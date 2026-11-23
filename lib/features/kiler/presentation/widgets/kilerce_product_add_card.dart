import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/kiler_models.dart';
import '../../domain/kiler_service.dart';

class KilerceProductAddCard extends StatefulWidget {
  final String? barcode;
  final String productName;
  final String brand;
  final int healthScore;
  final String? netQuantity;
  final List<String> marketChains;

  const KilerceProductAddCard({
    super.key,
    required this.barcode,
    required this.productName,
    required this.brand,
    required this.healthScore,
    this.netQuantity,
    this.marketChains = const [],
  });

  @override
  State<KilerceProductAddCard> createState() => _KilerceProductAddCardState();
}

class _KilerceProductAddCardState extends State<KilerceProductAddCard> {
  StorageZone? _selectedZone;
  bool _addedToPantry = false;
  bool _addedToShopping = false;

  String? get _cleanNetQuantity {
    final String? raw = widget.netQuantity?.trim();
    return (raw != null && raw.isNotEmpty) ? raw : null;
  }

  List<String> get _cleanMarketChains {
    final List<String> chains = <String>[];
    final Set<String> seen = <String>{};
    for (final String item in widget.marketChains) {
      final String trimmed = item.trim();
      if (trimmed.isNotEmpty && seen.add(trimmed.toLowerCase())) {
        chains.add(trimmed);
      }
    }
    return chains;
  }

  @override
  void initState() {
    super.initState();
    final resolved = IngredientNormalizer.resolveMetadata(
      widget.productName,
      healthScore: widget.healthScore,
    );
    _selectedZone = resolved.defaultZone;
  }

  Future<void> _addToPantry(StorageZone zone) async {
    setState(() {
      _selectedZone = zone;
      _addedToPantry = true;
    });

    await KilerService.instance.addScannedProduct(
      name: widget.productName,
      brand: widget.brand,
      barcode: widget.barcode,
      healthScore: widget.healthScore,
      overrideZone: zone,
      unitLabel: _cleanNetQuantity,
    );

    if (!mounted) return;
    final String qtySuffix =
        _cleanNetQuantity != null ? ' ($_cleanNetQuantity)' : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${zone.emoji} "${widget.productName}"$qtySuffix ${zone.label}na kaydedildi!',
        ),
        backgroundColor: AppColors.primaryEmerald,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _addToShoppingList() async {
    setState(() => _addedToShopping = true);
    await KilerService.instance.addShoppingItem(
      name: widget.productName,
      sourceNote: 'Barkod taramasından eklendi (${widget.brand})',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🛒 "${widget.productName}" Alışveriş Listesine eklendi!'),
        backgroundColor: AppColors.primaryMint,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = context.surfaceColor;
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;
    final borderColor = context.cardBorderColor;
    final activeZone = _selectedZone ?? StorageZone.pantry;
    final String? cleanQty = _cleanNetQuantity;
    final List<String> cleanChains = _cleanMarketChains;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primaryEmerald.withValues(alpha: 0.45),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryEmerald.withValues(alpha: 0.08),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryEmerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.kitchen_rounded,
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
                      'Kilerce Akıllı Envanter',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Bu ürünü aldınız mı? Dolaba ekleyin, uygun yemek tarifleri açılsın.',
                      style: TextStyle(color: textSecondary, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (cleanQty != null || cleanChains.isNotEmpty) ...[
            const SizedBox(height: 10),
            _KilerHeaderBadges(
              netQuantity: cleanQty,
              marketChains: cleanChains,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: StorageZone.values.map((zone) {
              final isSelected = zone == activeZone;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    onTap: () => _addToPantry(zone),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryEmerald.withValues(alpha: 0.16)
                            : Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppColors.primaryEmerald : borderColor,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(zone.emoji, style: const TextStyle(fontSize: 16)),
                          const SizedBox(height: 2),
                          Text(
                            zone.label.split(' ').first,
                            style: TextStyle(
                              color: isSelected
                                  ? AppColors.primaryEmerald
                                  : textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: () => _addToPantry(activeZone),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryEmerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(
                    _addedToPantry
                        ? Icons.check_circle_rounded
                        : Icons.add_home_work_rounded,
                    size: 18,
                  ),
                  label: Text(
                    _addedToPantry
                        ? 'Dolaba Kaydedildi (${activeZone.label.split(' ').first})'
                        : '${activeZone.emoji} ${activeZone.label}na Ekle',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: _addToShoppingList,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textPrimary,
                    side: BorderSide(color: borderColor),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(
                    _addedToShopping
                        ? Icons.check_rounded
                        : Icons.add_shopping_cart_rounded,
                    size: 16,
                    color: AppColors.primaryMint,
                  ),
                  label: Text(
                    _addedToShopping ? 'Listede' : 'Listeye',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KilerHeaderBadges extends StatelessWidget {
  final String? netQuantity;
  final List<String> marketChains;

  const _KilerHeaderBadges({
    this.netQuantity,
    this.marketChains = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (netQuantity != null)
          _KilerMetaPill(
            icon: Icons.scale_rounded,
            label: netQuantity!,
            accentColor: AppColors.primaryEmerald,
          ),
        ...marketChains.take(5).map(
              (String chain) => _KilerMetaPill(
                icon: Icons.storefront_rounded,
                label: chain,
                accentColor: AppColors.primaryMint,
              ),
            ),
      ],
    );
  }
}

class _KilerMetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accentColor;

  const _KilerMetaPill({
    required this.icon,
    required this.label,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = context.isDarkMode;
    final Color textPrimary = context.textPrimaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: accentColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
