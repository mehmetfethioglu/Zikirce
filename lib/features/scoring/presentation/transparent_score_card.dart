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
  bool _isExpanded = false;

  Color _getMatchColor(BuildContext context, int percentage) {
    if (percentage >= 80) return context.accentPrimary;
    if (percentage >= 60) return context.accentSecondary;
    if (percentage >= 40) return context.accentWarm;
    return context.accentDanger;
  }

  Color _getMatchTint(BuildContext context, int percentage) {
    if (percentage >= 60) return context.pastelSageTint;
    if (percentage >= 40) return context.pastelPeachTint;
    return context.pastelBlushTint;
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = context.surfaceColor;
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;
    final borderColor = context.borderColor;

    final match = widget.personalMatch;
    final matchColor = match != null
        ? _getMatchColor(context, match.matchPercentage)
        : context.accentPrimary;
    final matchTint = match != null
        ? _getMatchTint(context, match.matchPercentage)
        : context.pastelSageTint;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BioMinimalUi.cardDecoration(context, radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Personal Match Header Banner
          if (match != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: matchTint,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(19)),
                border: Border(
                  bottom: BorderSide(color: matchColor.withValues(alpha: 0.18)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: surfaceColor,
                      border: Border.all(
                        color: matchColor.withValues(alpha: 0.45),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '%${match.matchPercentage}',
                        style: TextStyle(
                          color: matchColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          match.statusLabel,
                          style: TextStyle(
                            color: matchColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${match.profileName} hedeflerine göre',
                          style: TextStyle(color: textSecondary, fontSize: 11.5),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.tune_rounded,
                              size: 14,
                              color: context.accentSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Ayarla',
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
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
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: match == null
                ? BorderRadius.circular(20)
                : const BorderRadius.vertical(bottom: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
              child: Row(
                children: [
                  Icon(
                    Icons.receipt_long_rounded,
                    color: context.accentPrimary,
                    size: 19,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Açık Puan Karnesi',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Puan kesintileri ve kazanımları',
                          style: TextStyle(color: textSecondary, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: textSecondary,
                  ),
                ],
              ),
            ),
          ),

          // 3. Itemized Ledger Rows (Collapsible)
          if (_isExpanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: [
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
                    ...widget.scoreResult.factors.map(
                      (f) => _buildFactorTile(
                        context,
                        factor: f,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                    ),
                  if (match != null && match.personalFactors.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 6,
                      ),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Kişisel Hassasiyet Etkileri',
                        style: TextStyle(
                          color: context.accentLavender,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    ...match.personalFactors.map(
                      (f) => _buildPersonalFactorTile(
                        context,
                        factor: f,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFactorTile(
    BuildContext context, {
    required ScoreFactor factor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final bool isBonus = factor.isPositive && factor.impact > 0;
    final bool isZeroNeutral = factor.impact == 0;
    final Color badgeColor = isBonus
        ? context.accentPrimary
        : isZeroNeutral
            ? context.accentSecondary
            : context.accentDanger;
    final Color tileBg = isBonus || isZeroNeutral
        ? context.pastelSageTint
        : context.pastelBlushTint;

    final String impactText = isBonus
        ? '+${factor.impact}'
        : isZeroNeutral
            ? 'Temiz'
            : '${factor.impact}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              impactText,
              style: TextStyle(
                color: badgeColor,
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
              ),
            ),
          ),
          const SizedBox(width: 10),
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
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (factor.standardRef != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: context.surfaceColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          factor.standardRef!,
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  factor.description,
                  style: TextStyle(color: textSecondary, fontSize: 11.5),
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
  }) {
    final bool isBonus = factor.isPositive && factor.impact >= 0;
    final Color badgeColor =
        isBonus ? context.accentPrimary : context.accentWarm;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.pastelLavenderTint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              factor.impact > 0 ? '+${factor.impact}%' : '${factor.impact}%',
              style: TextStyle(
                color: badgeColor,
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  factor.title,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  factor.description,
                  style: TextStyle(color: textSecondary, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
