import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../providers/gamification_providers.dart';
import '../../services/daily_streak_service.dart';
import 'streak_recovery_dialog.dart';

class GoldDiamondExchangeSheet extends ConsumerStatefulWidget {
  const GoldDiamondExchangeSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const GoldDiamondExchangeSheet(),
    );
  }

  @override
  ConsumerState<GoldDiamondExchangeSheet> createState() =>
      _GoldDiamondExchangeSheetState();
}

class _GoldDiamondExchangeSheetState
    extends ConsumerState<GoldDiamondExchangeSheet> {
  int _selectedTab = 0; // 0: Altın ➔ Elmas, 1: Elmas ➔ Kalkan
  int _diamondsToBuy = 1;
  int _shieldsToBuy = 1;
  bool _isProcessing = false;

  void _selectDiamondPack(int diamonds, int maxPossible) {
    HapticFeedback.selectionClick();
    setState(() {
      _diamondsToBuy = diamonds.clamp(1, maxPossible > 0 ? maxPossible : 1);
    });
  }

  void _selectShieldPack(int shields, int maxPossible) {
    HapticFeedback.selectionClick();
    setState(() {
      _shieldsToBuy = shields.clamp(1, maxPossible > 0 ? maxPossible : 1);
    });
  }

  Future<void> _performGoldExchange(int goldCount) async {
    final goldCost = _diamondsToBuy * 5;
    if (goldCount < goldCost || _isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    final success = await ref
        .read(gamificationNotifierProvider)
        .convertGoldToDiamonds(goldCost);

    if (mounted) {
      setState(() {
        _isProcessing = false;
      });

      final l10n = context.l10n;
      if (success) {
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Text('💎', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.isTurkish
                        ? '$_diamondsToBuy Elmas hesabınıza eklendi!'
                        : '$_diamondsToBuy Diamonds added to your account!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF0D9488),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.translate('Exchange_InsufficientGold')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _performShieldExchange(int diamondsCount) async {
    final diamondCost = _shieldsToBuy * 5;
    if (diamondsCount < diamondCost || _isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    final success = await ref
        .read(gamificationNotifierProvider)
        .buyShieldWithDiamonds(_shieldsToBuy);

    if (mounted) {
      setState(() {
        _isProcessing = false;
      });

      final l10n = context.l10n;
      if (success) {
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop();

        // Check if there is a repairable broken streak to recommend recovery
        final db = ref.read(databaseProvider);
        final hasRepairable =
            await DailyStreakService.hasRepairableHistoricalStreak(db);
        if (hasRepairable && mounted) {
          final streak =
              (await (db.select(db.userStreaks)..limit(1)).get()).firstOrNull;
          final unrepaired = await DailyStreakService.getUnrepairedGapDays(db);
          if (streak != null && mounted) {
            await StreakRecoveryDialog.show(
              context,
              bestStreak: streak.bestStreak,
              currentStreak: streak.currentStreak,
              availableShields: streak.freezeCount,
              remainingGaps: unrepaired.isEmpty ? 1 : unrepaired.length,
            );
            return;
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Text('🛡️', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.isTurkish
                          ? '$_shieldsToBuy Seri Koruma Kalkanı envanterinize eklendi!'
                          : '$_shieldsToBuy Streak Shield(s) added to inventory!',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF059669),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.isTurkish ? 'Yetersiz Elmas!' : 'Insufficient Diamonds!',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    final goldAsync = ref.watch(goldCountProvider);
    final diamondsAsync = ref.watch(diamondCountProvider);
    final streakAsync = ref.watch(userStreakStreamProvider);
    final streak = streakAsync.valueOrNull;

    final int goldCount = goldAsync.valueOrNull ?? 0;
    final int diamondsCount = diamondsAsync.valueOrNull ?? 0;
    final int shieldCount = streak?.freezeCount ?? 3;

    final int maxPossibleDiamonds = goldCount ~/ 5;
    final int requiredGold = _diamondsToBuy * 5;
    final bool canAffordDiamonds = goldCount >= requiredGold && requiredGold > 0;

    final int maxPossibleShields = diamondsCount ~/ 5;
    final int requiredDiamonds = _shieldsToBuy * 5;
    final bool canAffordShields =
        diamondsCount >= requiredDiamonds && requiredDiamonds > 0;

    return Container(
      padding: EdgeInsets.fromLTRB(
        22,
        14,
        22,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: colors.bottomSheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: colors.borderStroke,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Row
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFF0284C7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      _selectedTab == 0 ? '🪙➔💎' : '💎➔🛡️',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.isTurkish ? 'Hazine ve Takas' : 'Treasury & Exchange',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedTab == 0
                            ? (l10n.isTurkish
                                ? 'Altınlarınızı değerli elmaslara dönüştürün'
                                : 'Convert gold to diamonds')
                            : (l10n.isTurkish
                                ? 'Elmas ile seri koruyucu kalkan edinin'
                                : 'Get streak protection shields with diamonds'),
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.secondaryTextAlt,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: colors.secondaryTextAlt),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tab Switcher (Altın ➔ Elmas  |  Elmas ➔ Kalkan)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colors.cardBackgroundAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.borderStroke.withValues(alpha: 0.6)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedTab = 0);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedTab == 0
                              ? const Color(0xFF0284C7)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('🪙➔💎', style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 6),
                            Text(
                              l10n.isTurkish ? 'Altın ➔ Elmas' : 'Gold ➔ Diamond',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: _selectedTab == 0
                                    ? Colors.white
                                    : colors.primaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedTab = 1);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedTab == 1
                              ? const Color(0xFF059669)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('💎➔🛡️', style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 6),
                            Text(
                              l10n.isTurkish ? 'Elmas ➔ Kalkan' : 'Diamond ➔ Shield',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: _selectedTab == 1
                                    ? Colors.white
                                    : colors.primaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Balances Status Bar (Gold, Diamond, Shield)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colors.cardBackgroundAlt,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.borderStroke.withValues(alpha: 0.6)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Gold Balance
                  Row(
                    children: [
                      const Text('🪙', style: TextStyle(fontSize: 17)),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.isTurkish ? 'Altın' : 'Gold',
                            style: TextStyle(
                              fontSize: 10,
                              color: colors.secondaryTextAlt,
                            ),
                          ),
                          Text(
                            '$goldCount',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(height: 26, width: 1, color: colors.borderStroke),
                  // Diamond Balance
                  Row(
                    children: [
                      const Text('💎', style: TextStyle(fontSize: 17)),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.isTurkish ? 'Elmas' : 'Diamond',
                            style: TextStyle(
                              fontSize: 10,
                              color: colors.secondaryTextAlt,
                            ),
                          ),
                          Text(
                            '$diamondsCount',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0284C7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(height: 26, width: 1, color: colors.borderStroke),
                  // Shield Balance
                  Row(
                    children: [
                      const Text('🛡️', style: TextStyle(fontSize: 17)),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.isTurkish ? 'Kalkan' : 'Shield',
                            style: TextStyle(
                              fontSize: 10,
                              color: colors.secondaryTextAlt,
                            ),
                          ),
                          Text(
                            '$shieldCount',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Rate Notice Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: (_selectedTab == 0
                        ? const Color(0xFF0284C7)
                        : const Color(0xFF059669))
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (_selectedTab == 0
                          ? const Color(0xFF0284C7)
                          : const Color(0xFF059669))
                      .withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: _selectedTab == 0
                        ? const Color(0xFF0284C7)
                        : const Color(0xFF059669),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _selectedTab == 0
                        ? (l10n.isTurkish
                            ? '5 Altın (🪙) = 1 Elmas (💎)'
                            : '5 Gold (🪙) = 1 Diamond (💎)')
                        : (l10n.isTurkish
                            ? '5 Elmas (💎) = 1 Kalkan (🛡️)'
                            : '5 Diamonds (💎) = 1 Shield (🛡️)'),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _selectedTab == 0
                          ? const Color(0xFF0284C7)
                          : const Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            if (_selectedTab == 0) ...[
              // Quick Packages for Diamonds
              Text(
                l10n.translate('Exchange_QuickPacks'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colors.primaryText,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildQuickPackChip(
                    label: '1 💎',
                    amount: 1,
                    cost: 5,
                    currencySymbol: '🪙',
                    isSelected: _diamondsToBuy == 1,
                    maxPossible: maxPossibleDiamonds,
                    colors: colors,
                    onTap: () => _selectDiamondPack(1, maxPossibleDiamonds),
                  ),
                  const SizedBox(width: 6),
                  _buildQuickPackChip(
                    label: '5 💎',
                    amount: 5,
                    cost: 25,
                    currencySymbol: '🪙',
                    isSelected: _diamondsToBuy == 5,
                    maxPossible: maxPossibleDiamonds,
                    colors: colors,
                    onTap: () => _selectDiamondPack(5, maxPossibleDiamonds),
                  ),
                  const SizedBox(width: 6),
                  _buildQuickPackChip(
                    label: '10 💎',
                    amount: 10,
                    cost: 50,
                    currencySymbol: '🪙',
                    isSelected: _diamondsToBuy == 10,
                    maxPossible: maxPossibleDiamonds,
                    colors: colors,
                    onTap: () => _selectDiamondPack(10, maxPossibleDiamonds),
                  ),
                  const SizedBox(width: 6),
                  _buildQuickPackChip(
                    label: l10n.translate('Exchange_PackAll'),
                    amount: maxPossibleDiamonds > 0 ? maxPossibleDiamonds : 1,
                    cost: (maxPossibleDiamonds > 0 ? maxPossibleDiamonds : 1) * 5,
                    currencySymbol: '🪙',
                    isSelected: maxPossibleDiamonds > 0 &&
                        _diamondsToBuy == maxPossibleDiamonds,
                    maxPossible: maxPossibleDiamonds,
                    colors: colors,
                    onTap: () => _selectDiamondPack(
                        maxPossibleDiamonds > 0 ? maxPossibleDiamonds : 1,
                        maxPossibleDiamonds),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Quantity Stepper Selector
              _buildStepper(
                title: l10n.translate('Exchange_AmountToConvert'),
                amount: _diamondsToBuy,
                symbol: '💎',
                onDecrement: _diamondsToBuy > 1
                    ? () {
                        HapticFeedback.selectionClick();
                        setState(() => _diamondsToBuy--);
                      }
                    : null,
                onIncrement: _diamondsToBuy < maxPossibleDiamonds
                    ? () {
                        HapticFeedback.selectionClick();
                        setState(() => _diamondsToBuy++);
                      }
                    : null,
                colors: colors,
              ),
              const SizedBox(height: 14),

              // Convert Action Button
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: (canAffordDiamonds && !_isProcessing)
                      ? () => _performGoldExchange(goldCount)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    disabledBackgroundColor: colors.borderStroke,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('💎', style: TextStyle(fontSize: 15)),
                            const SizedBox(width: 6),
                            Text(
                              canAffordDiamonds
                                  ? '$requiredGold 🪙 ➔ +$_diamondsToBuy 💎 Dönüştür'
                                  : (l10n.isTurkish ? 'Yetersiz Altın' : 'Insufficient Gold'),
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                ),
              ),
            ] else ...[
              // Quick Packages for Shields
              Text(
                l10n.isTurkish ? 'Hızlı Kalkan Paketleri' : 'Quick Shield Packs',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colors.primaryText,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildQuickPackChip(
                    label: '1 🛡️',
                    amount: 1,
                    cost: 5,
                    currencySymbol: '💎',
                    isSelected: _shieldsToBuy == 1,
                    maxPossible: maxPossibleShields,
                    colors: colors,
                    onTap: () => _selectShieldPack(1, maxPossibleShields),
                  ),
                  const SizedBox(width: 6),
                  _buildQuickPackChip(
                    label: '2 🛡️',
                    amount: 2,
                    cost: 10,
                    currencySymbol: '💎',
                    isSelected: _shieldsToBuy == 2,
                    maxPossible: maxPossibleShields,
                    colors: colors,
                    onTap: () => _selectShieldPack(2, maxPossibleShields),
                  ),
                  const SizedBox(width: 6),
                  _buildQuickPackChip(
                    label: '3 🛡️',
                    amount: 3,
                    cost: 15,
                    currencySymbol: '💎',
                    isSelected: _shieldsToBuy == 3,
                    maxPossible: maxPossibleShields,
                    colors: colors,
                    onTap: () => _selectShieldPack(3, maxPossibleShields),
                  ),
                  const SizedBox(width: 6),
                  _buildQuickPackChip(
                    label: '5 🛡️',
                    amount: 5,
                    cost: 25,
                    currencySymbol: '💎',
                    isSelected: _shieldsToBuy == 5,
                    maxPossible: maxPossibleShields,
                    colors: colors,
                    onTap: () => _selectShieldPack(5, maxPossibleShields),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Quantity Stepper Selector
              _buildStepper(
                title: l10n.isTurkish
                    ? 'Alınacak Kalkan Sayısı'
                    : 'Shields to Purchase',
                amount: _shieldsToBuy,
                symbol: '🛡️',
                onDecrement: _shieldsToBuy > 1
                    ? () {
                        HapticFeedback.selectionClick();
                        setState(() => _shieldsToBuy--);
                      }
                    : null,
                onIncrement: _shieldsToBuy < maxPossibleShields
                    ? () {
                        HapticFeedback.selectionClick();
                        setState(() => _shieldsToBuy++);
                      }
                    : null,
                colors: colors,
              ),
              const SizedBox(height: 14),

              // Buy Shield Action Button
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: (canAffordShields && !_isProcessing)
                      ? () => _performShieldExchange(diamondsCount)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    disabledBackgroundColor: colors.borderStroke,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('🛡️', style: TextStyle(fontSize: 15)),
                            const SizedBox(width: 6),
                            Text(
                              canAffordShields
                                  ? '$requiredDiamonds 💎 ➔ +$_shieldsToBuy 🛡️ Kalkan Al'
                                  : (l10n.isTurkish
                                      ? 'Yetersiz Elmas'
                                      : 'Insufficient Diamonds'),
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStepper({
    required String title,
    required int amount,
    required String symbol,
    required VoidCallback? onDecrement,
    required VoidCallback? onIncrement,
    required AppThemeColors colors,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.cardBackgroundAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderStroke),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 11.5, color: colors.secondaryTextAlt),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    '$amount',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colors.primaryText,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(symbol, style: const TextStyle(fontSize: 16)),
                ],
              ),
            ],
          ),
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: onDecrement,
                style: IconButton.styleFrom(
                  backgroundColor: colors.cardBackground,
                  foregroundColor: colors.primaryText,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.remove_rounded, size: 18),
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                onPressed: onIncrement,
                style: IconButton.styleFrom(
                  backgroundColor: colors.cardBackground,
                  foregroundColor: colors.primaryText,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPackChip({
    required String label,
    required int amount,
    required int cost,
    required String currencySymbol,
    required bool isSelected,
    required int maxPossible,
    required AppThemeColors colors,
    required VoidCallback onTap,
  }) {
    final bool canAfford = maxPossible >= amount && amount > 0;
    final activeColor = _selectedTab == 0
        ? const Color(0xFF0284C7)
        : const Color(0xFF059669);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : colors.cardBackgroundAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? activeColor
                  : colors.borderStroke.withValues(alpha: 0.7),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : colors.primaryText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$cost $currencySymbol',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.9)
                      : (canAfford
                          ? (_selectedTab == 0
                              ? const Color(0xFFD97706)
                              : const Color(0xFF0284C7))
                          : colors.secondaryTextAlt),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
