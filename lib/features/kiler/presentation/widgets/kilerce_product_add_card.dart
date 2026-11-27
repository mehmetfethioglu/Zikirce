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

  String _shortZoneLabel(StorageZone zone) {
    switch (zone) {
      case StorageZone.fridge:
        return 'Buzdolabı';
      case StorageZone.pantry:
        return 'Kiler';
      case StorageZone.freezer:
        return 'Dondurucu';
    }
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
          '"${widget.productName}"$qtySuffix ${_shortZoneLabel(zone)} alanına kaydedildi.',
        ),
        backgroundColor: context.accentPrimary,
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
        content: Text('"${widget.productName}" alışveriş listesine eklendi.'),
        backgroundColor: context.accentSecondary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = context.textPrimaryColor;
    final borderColor = context.cardBorderColor;
    final activeZone = _selectedZone ?? StorageZone.pantry;
    final String? cleanQty = _cleanNetQuantity;
    final List<String> cleanChains = _cleanMarketChains;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BioMinimalUi.cardDecoration(context, radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Kilere Ekle',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (cleanQty != null || cleanChains.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _KilerHeaderBadges(
                    netQuantity: cleanQty,
                    marketChains: cleanChains,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: StorageZone.values.map((zone) {
              final isSelected = zone == activeZone;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: zone == StorageZone.freezer ? 0 : 6,
                  ),
                  child: InkWell(
                    onTap: () => setState(() => _selectedZone = zone),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                        vertical: 9,
                        horizontal: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? context.pastelSageTint
                            : context.subtleSurfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? context.accentPrimary.withValues(alpha: 0.4)
                              : borderColor,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            zone.icon,
                            size: 15,
                            color: isSelected
                                ? context.accentPrimary
                                : context.textSecondaryColor,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              _shortZoneLabel(zone),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isSelected
                                    ? context.accentPrimary
                                    : textPrimary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
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
                    backgroundColor: context.accentPrimary,
                    foregroundColor: context.onAccentPrimary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(
                    _addedToPantry
                        ? Icons.check_circle_rounded
                        : Icons.add_rounded,
                    size: 18,
                  ),
                  label: Text(
                    _addedToPantry ? 'Kaydedildi' : 'Dolaba Ekle',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextButton.icon(
                  onPressed: _addToShoppingList,
                  style: TextButton.styleFrom(
                    backgroundColor: context.subtleSurfaceColor,
                    foregroundColor: textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(
                    _addedToShopping
                        ? Icons.check_rounded
                        : Icons.add_shopping_cart_rounded,
                    size: 16,
                    color: context.accentSecondary,
                  ),
                  label: Text(
                    _addedToShopping ? 'Listede' : 'Listeye',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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
      spacing: 5,
      runSpacing: 5,
      alignment: WrapAlignment.end,
      children: [
        if (netQuantity != null)
          _KilerMetaPill(
            label: netQuantity!,
            bgColor: context.pastelSageTint,
            fgColor: context.accentPrimary,
          ),
        ...marketChains.take(3).map(
              (String chain) => _KilerMetaPill(
                label: chain,
                bgColor: context.subtleSurfaceColor,
                fgColor: context.textSecondaryColor,
              ),
            ),
      ],
    );
  }
}

class _KilerMetaPill extends StatelessWidget {
  final String label;
  final Color bgColor;
  final Color fgColor;

  const _KilerMetaPill({
    required this.label,
    required this.bgColor,
    required this.fgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fgColor,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
