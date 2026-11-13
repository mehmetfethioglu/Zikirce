import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../gamification/presentation/widgets/gold_diamond_exchange_sheet.dart';
import '../../../gamification/providers/gamification_providers.dart';
import '../../domain/irfan_models.dart';

/// Selected payment currency when opening a paid İrfan session.
enum IrfanEntryPaymentChoice {
  gold,
  diamonds,
}

/// Modal confirmation sheet presenting İrfan session entry fee, Smart Hourglass rule, and live balance.
class IrfanSessionEntrySheet extends ConsumerWidget {
  final String title;
  final String subtitle;
  final int? goldCost;
  final int? diamondCost;

  const IrfanSessionEntrySheet({
    super.key,
    required this.title,
    required this.subtitle,
    this.goldCost,
    this.diamondCost,
  });

  static Future<IrfanEntryPaymentChoice?> show(
    BuildContext context, {
    required String title,
    required String subtitle,
    int? goldCost,
    int? diamondCost,
  }) {
    return showModalBottomSheet<IrfanEntryPaymentChoice>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => IrfanSessionEntrySheet(
        title: title,
        subtitle: subtitle,
        goldCost: goldCost,
        diamondCost: diamondCost,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final isTr = context.l10n.isTurkish;
    final gold = ref.watch(goldCountProvider.select((v) => v.valueOrNull ?? 0));
    final diamonds =
        ref.watch(diamondCountProvider.select((v) => v.valueOrNull ?? 0));

    final bool hasGold = goldCost != null;
    final bool hasDiamond = diamondCost != null;
    final bool canPayGold = hasGold && gold >= goldCost!;
    final bool canPayDiamond = hasDiamond && diamonds >= diamondCost!;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: BoxDecoration(
        color: colors.bottomSheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.secondaryTextAlt.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  alignment: Alignment.center,
                  child: const Text('⏳', style: TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                          color: colors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: colors.secondaryTextAlt,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colors.accent.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.hourglass_bottom_rounded,
                    size: 18,
                    color: colors.accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isTr
                          ? '${IrfanEconomyConfig.initialSessionSeconds} sn Akıllı Kum Saati • Hikmet ve Külliyat okurken süre durur.'
                          : '${IrfanEconomyConfig.initialSessionSeconds}s Smart Hourglass • Pauses while reading wisdom & books.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                        color: colors.primaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colors.cardBackgroundAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.borderStroke),
              ),
              child: Row(
                children: [
                  Text(
                    isTr ? 'Mevcut Bakiye:' : 'Your Balance:',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: colors.secondaryTextAlt,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '🪙 $gold   •   💎 $diamonds',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: colors.primaryText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (hasGold && hasDiamond)
              Row(
                children: [
                  Expanded(
                    child: _EntryCurrencyOptionButton(
                      label: '🪙 $goldCost ${isTr ? 'Altın' : 'Gold'}',
                      enabled: canPayGold,
                      isPrimary: true,
                      onPressed: () {
                        HapticService.selectionClick();
                        Navigator.of(context).pop(IrfanEntryPaymentChoice.gold);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _EntryCurrencyOptionButton(
                      label: '💎 $diamondCost ${isTr ? 'Elmas' : 'Diamond'}',
                      enabled: canPayDiamond,
                      isPrimary: false,
                      onPressed: () {
                        HapticService.selectionClick();
                        Navigator.of(context)
                            .pop(IrfanEntryPaymentChoice.diamonds);
                      },
                    ),
                  ),
                ],
              )
            else if (hasGold)
              SizedBox(
                width: double.infinity,
                child: _EntryCurrencyOptionButton(
                  label: isTr
                      ? '🪙 $goldCost Altın ile Başlat'
                      : '🪙 Start with $goldCost Gold',
                  enabled: canPayGold,
                  isPrimary: true,
                  onPressed: () {
                    HapticService.selectionClick();
                    Navigator.of(context).pop(IrfanEntryPaymentChoice.gold);
                  },
                ),
              )
            else if (hasDiamond)
              SizedBox(
                width: double.infinity,
                child: _EntryCurrencyOptionButton(
                  label: isTr
                      ? '💎 $diamondCost Elmas ile Başlat'
                      : '💎 Start with $diamondCost Diamonds',
                  enabled: canPayDiamond,
                  isPrimary: true,
                  onPressed: () {
                    HapticService.selectionClick();
                    Navigator.of(context).pop(IrfanEntryPaymentChoice.diamonds);
                  },
                ),
              ),
            if ((hasGold && !canPayGold) || (hasDiamond && !canPayDiamond)) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  isTr
                      ? 'Yetersiz bakiye: Zikir ve Kur\'an okuyarak Altın kazanabilir veya dönüştürebilirsiniz.'
                      : 'Insufficient balance: Earn Gold via Dhikr & Qur\'an or convert below.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: colors.secondaryTextAlt,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 6),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  HapticService.selectionClick();
                  GoldDiamondExchangeSheet.show(context);
                },
                icon: Icon(
                  Icons.swap_horiz_rounded,
                  size: 18,
                  color: colors.accent,
                ),
                label: Text(
                  isTr
                      ? 'Altın ➔ Elmas Dönüştür (5 🪙 = 1 💎)'
                      : 'Convert Gold ➔ Diamond (5 🪙 = 1 💎)',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: colors.accent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryCurrencyOptionButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final bool isPrimary;
  final VoidCallback onPressed;

  const _EntryCurrencyOptionButton({
    required this.label,
    required this.enabled,
    required this.isPrimary,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (isPrimary) {
      return ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.accent,
          disabledBackgroundColor: colors.borderStroke,
          foregroundColor: Colors.white,
          disabledForegroundColor: colors.secondaryTextAlt,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return OutlinedButton(
      onPressed: enabled ? onPressed : null,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        side: BorderSide(
          color: enabled ? colors.accent : colors.borderStroke,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.bold,
          color: enabled ? colors.primaryText : colors.secondaryTextAlt,
        ),
      ),
    );
  }
}
