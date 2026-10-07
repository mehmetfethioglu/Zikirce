import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../family_profiles/domain/family_profile_engine.dart';
import '../domain/organic_score_calculator.dart';
import 'personal_sensitivity_modal.dart';

class TransparentScoreCard extends StatefulWidget {
  final OrganicScoreResult scoreResult;
  final PersonalMatchResult? personalMatch;
  final FamilyProfile? activeProfile;
  final VoidCallback? onSensitivityChanged;

  const TransparentScoreCard({
    super.key,
    required this.scoreResult,
    this.personalMatch,
    this.activeProfile,
    this.onSensitivityChanged,
  });

  @override
  State<TransparentScoreCard> createState() => _TransparentScoreCardState();
}

class _TransparentScoreCardState extends State<TransparentScoreCard> {
  bool _isExpanded = true;

  Color _getMatchColor(int percentage) {
    if (percentage >= 80) return AppColors.primaryEmerald;
    if (percentage >= 60) return AppColors.primaryMint;
    if (percentage >= 40) return AppColors.cautionGold;
    return AppColors.dangerRed;
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = context.surfaceColor;
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;
    final borderColor = context.borderColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final match = widget.personalMatch;
    final matchColor = match != null ? _getMatchColor(match.matchPercentage) : AppColors.primaryEmerald;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Personal Match Header Banner
          if (match != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: matchColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(bottom: BorderSide(color: matchColor.withValues(alpha: 0.2))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: matchColor.withValues(alpha: 0.2),
                      border: Border.all(color: matchColor, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        '%${match.matchPercentage}',
                        style: TextStyle(
                          color: matchColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              match.statusLabel,
                              style: TextStyle(
                                color: matchColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${match.profileName} Sağlık Hedeflerine Göre',
                          style: TextStyle(color: textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  if (widget.activeProfile != null)
                    InkWell(
                      onTap: () {
                        PersonalSensitivityModal.show(
                          context,
                          profile: widget.activeProfile!,
                          onSaved: widget.onSensitivityChanged,
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.tune_rounded, size: 14, color: AppColors.primaryMint),
                            const SizedBox(width: 4),
                            Text(
                              'Ayarlar',
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],

          // 2. Score Breakdown Title & Collapse Toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_rounded, color: AppColors.primaryEmerald, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Açık Puan Karnesi',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Şeffaf puan kesintileri ve kazanımları',
                        style: TextStyle(color: textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                  icon: Icon(
                    _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: textSecondary,
                  ),
                  tooltip: _isExpanded ? 'Daralt' : 'Genişlet',
                ),
              ],
            ),
          ),

          // 3. Itemized Ledger Rows (Collapsible)
          if (_isExpanded) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  // Universal OrganicScore factors
                  if (widget.scoreResult.factors.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Bu ürün için ayrıntılı bileşen dökümü henüz kaydedilmedi.',
                        style: TextStyle(color: textSecondary, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ...widget.scoreResult.factors.map((f) => _buildFactorTile(
                          context,
                          factor: f,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          borderColor: borderColor,
                        )),

                  // Personal Match adjustments
                  if (match != null && match.personalFactors.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Kişisel Hassasiyet Etkileri:',
                        style: TextStyle(
                          color: Colors.purpleAccent.shade100,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    ...match.personalFactors.map((f) => _buildPersonalFactorTile(
                          context,
                          factor: f,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          borderColor: borderColor,
                        )),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildFactorTile(
    BuildContext context, {
    required ScoreFactor factor,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    final bool isBonus = factor.isPositive && factor.impact > 0;
    final bool isZeroNeutral = factor.impact == 0;
    final Color badgeColor = isBonus
        ? AppColors.primaryEmerald
        : isZeroNeutral
            ? AppColors.primaryMint
            : AppColors.dangerRed;

    final String impactText = isBonus
        ? '+${factor.impact}'
        : isZeroNeutral
            ? '✓ Temiz'
            : '${factor.impact}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: badgeColor.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              impactText,
              style: TextStyle(
                color: badgeColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        factor.title,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (factor.standardRef != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: borderColor.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          factor.standardRef!,
                          style: TextStyle(color: textSecondary, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  factor.description,
                  style: TextStyle(color: textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalFactorTile(
    BuildContext context, {
    required ScoreFactor factor,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    final bool isBonus = factor.isPositive && factor.impact >= 0;
    final Color badgeColor = isBonus ? Colors.tealAccent.shade400 : Colors.deepOrangeAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              factor.impact > 0 ? '+${factor.impact}%' : '${factor.impact}%',
              style: TextStyle(
                color: badgeColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  factor.title,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  factor.description,
                  style: TextStyle(color: textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
