import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../domain/irfan_models.dart';
import 'irfan_seljuk_star_painter.dart';

/// 4 Ana İlim Sütunu x 3 Kademe (Başlangıç / Orta / İrfan) Ustalık Haritası.
class IrfanTopicMapGrid extends StatelessWidget {
  final Map<(IrfanTopic, IrfanTier), double> masteryByNode;
  final void Function(IrfanTopic topic, IrfanTier tier) onSelectTopicTier;
  final VoidCallback? onOpenLibraryTab;

  const IrfanTopicMapGrid({
    super.key,
    required this.masteryByNode,
    required this.onSelectTopicTier,
    this.onOpenLibraryTab,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IrfanSeljukStarBadge(
              size: 22,
              color: colors.accent,
              accentColor: const Color(0xFFD4A574),
              filled: false,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.irfanTopicMapTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colors.primaryText,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final topic in IrfanTopic.values) ...[
          _IrfanTopicNodeCard(
            topic: topic,
            baslangicMastery:
                masteryByNode[(topic, IrfanTier.baslangic)] ?? 0.0,
            ortaMastery: masteryByNode[(topic, IrfanTier.orta)] ?? 0.0,
            irfanMastery: masteryByNode[(topic, IrfanTier.irfan)] ?? 0.0,
            onSelectTier: (tier) => onSelectTopicTier(topic, tier),
            onOpenLibraryTab:
                topic == IrfanTopic.ilmihal32Farz ? onOpenLibraryTab : null,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _IrfanTopicNodeCard extends StatelessWidget {
  final IrfanTopic topic;
  final double baslangicMastery;
  final double ortaMastery;
  final double irfanMastery;
  final ValueChanged<IrfanTier> onSelectTier;
  final VoidCallback? onOpenLibraryTab;

  const _IrfanTopicNodeCard({
    required this.topic,
    required this.baslangicMastery,
    required this.ortaMastery,
    required this.irfanMastery,
    required this.onSelectTier,
    this.onOpenLibraryTab,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isTr = context.l10n.isTurkish;
    final overallMastery =
        ((baslangicMastery + ortaMastery + irfanMastery) / 3.0).clamp(0.0, 1.0);
    final overallPercent = (overallMastery * 100).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.borderStroke, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(topic.emoji, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.label(isTr),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      topic.subtitle(isTr),
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: colors.secondaryTextAlt,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '%$overallPercent',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: colors.accent,
                  ),
                ),
              ),
            ],
          ),
          if (onOpenLibraryTab != null) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () {
                HapticService.selectionClick();
                onOpenLibraryTab!();
              },
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.menu_book_rounded,
                      size: 14,
                      color: colors.accent,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isTr
                          ? 'Önce 32 Farz İlmihalini Oku →'
                          : 'Read 32 Farz Catechism First →',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _IrfanTierButton(
                  tier: IrfanTier.baslangic,
                  mastery: baslangicMastery,
                  onTap: () => onSelectTier(IrfanTier.baslangic),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _IrfanTierButton(
                  tier: IrfanTier.orta,
                  mastery: ortaMastery,
                  onTap: () => onSelectTier(IrfanTier.orta),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _IrfanTierButton(
                  tier: IrfanTier.irfan,
                  mastery: irfanMastery,
                  onTap: () => onSelectTier(IrfanTier.irfan),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IrfanTierButton extends StatelessWidget {
  final IrfanTier tier;
  final double mastery;
  final VoidCallback onTap;

  const _IrfanTierButton({
    required this.tier,
    required this.mastery,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isTr = context.l10n.isTurkish;
    final clamped = mastery.clamp(0.0, 1.0);
    final isMastered = clamped >= 0.8;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticService.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: isMastered
                ? colors.accent.withValues(alpha: 0.11)
                : colors.cardBackgroundAlt,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: isMastered
                  ? colors.accent.withValues(alpha: 0.45)
                  : colors.borderStroke,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isMastered) ...[
                    Icon(
                      Icons.stars_rounded,
                      size: 13,
                      color: colors.accent,
                    ),
                    const SizedBox(width: 3),
                  ],
                  Flexible(
                    child: Text(
                      tier.label(isTr),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colors.primaryText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: clamped,
                  minHeight: 4.5,
                  backgroundColor: colors.borderStroke.withValues(alpha: 0.6),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isMastered ? const Color(0xFF10B981) : colors.accent,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '%${(clamped * 100).round()}',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: colors.secondaryTextAlt,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                IrfanEconomyConfig.tierCostBadgeLabel(tier),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: colors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
