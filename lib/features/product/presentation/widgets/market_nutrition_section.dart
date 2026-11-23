import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Immutable resolved nutrient item for 100g / 100ml TGK nutrition facts display.
class _ResolvedNutrient {
  final String label;
  final String formattedValue;
  final String unit;
  final Color accentColor;
  final IconData icon;

  const _ResolvedNutrient({
    required this.label,
    required this.formattedValue,
    required this.unit,
    required this.accentColor,
    required this.icon,
  });
}

/// Atomic, responsive TGK & Turkish Market product metadata section (SRP, 120 FPS const-first).
/// Renders only the subsections that carry verified non-empty data.
class MarketNutritionSection extends StatelessWidget {
  final Map<String, double> nutriments;
  final String ingredientsText;
  final List<String> marketChains;
  final List<String> allergens;
  final String? netQuantity;
  final String? legalProducer;
  final double? referencePriceTry;

  const MarketNutritionSection({
    super.key,
    required this.nutriments,
    this.ingredientsText = '',
    this.marketChains = const [],
    this.allergens = const [],
    this.netQuantity,
    this.legalProducer,
    this.referencePriceTry,
  });

  static List<String> _normalizeChains(List<String> rawChains) {
    const Map<String, String> canonicalMap = <String, String>{
      'bim': 'BİM',
      'bım': 'BİM',
      'bi̇m': 'BİM',
      'a101': 'A101',
      'sok': 'ŞOK',
      'şok': 'ŞOK',
      'ceptesok': 'ŞOK',
      'migros': 'Migros',
      'carrefour': 'CarrefourSA',
      'carrefoursa': 'CarrefourSA',
      'tarim kredi': 'Tarım Kredi',
      'tarım kredi': 'Tarım Kredi',
      'tarim_kredi': 'Tarım Kredi',
      'tarimkredi': 'Tarım Kredi',
      'hakmar': 'Hakmar',
      'file': 'FİLE',
    };

    final List<String> result = <String>[];
    final Set<String> seen = <String>{};
    for (final String raw in rawChains) {
      final String trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      final String mapped =
          canonicalMap[trimmed.toLowerCase()] ?? trimmed;
      if (seen.add(mapped.toLowerCase())) {
        result.add(mapped);
      }
    }
    return result;
  }

  static List<String> _normalizeAllergens(List<String> rawAllergens) {
    final List<String> result = <String>[];
    final Set<String> seen = <String>{};
    for (final String entry in rawAllergens) {
      final String trimmed = entry.trim();
      if (trimmed.isEmpty) continue;
      final List<String> parts = trimmed.length <= 64 && trimmed.contains(',')
          ? trimmed.split(',')
          : <String>[trimmed];
      for (final String part in parts) {
        final String clean = part.trim();
        if (clean.isEmpty) continue;
        final String lower = clean.toLowerCase();
        if (lower == 'yok' ||
            lower == 'yoktur' ||
            lower == '-' ||
            lower.contains('alerjen içermez') ||
            lower.contains('alerjen icermez')) {
          continue;
        }
        if (seen.add(lower)) {
          result.add(clean);
        }
      }
    }
    return result;
  }

  static double? _lookupValue(Map<String, double> map, List<String> keys) {
    for (final String key in keys) {
      final double? val = map[key];
      if (val != null && val.isFinite && val >= 0) {
        return val;
      }
    }
    return null;
  }

  static String _formatAmount(double value, {bool isKcal = false}) {
    if (isKcal) {
      return (value - value.roundToDouble()).abs() < 0.05
          ? value.round().toString()
          : value.toStringAsFixed(1);
    }
    if ((value - value.roundToDouble()).abs() < 0.005) {
      return value.toStringAsFixed(1);
    }
    final String twoDecimals = value.toStringAsFixed(2);
    return twoDecimals.endsWith('0')
        ? value.toStringAsFixed(1)
        : twoDecimals;
  }

  static List<_ResolvedNutrient> _resolveNutrients(Map<String, double> map) {
    if (map.isEmpty) return const <_ResolvedNutrient>[];

    final List<_ResolvedNutrient> items = <_ResolvedNutrient>[];

    final double? energyKcal = _lookupValue(map, const <String>[
      'energy_kcal',
      'energy-kcal_100g',
      'energy_kcal_100g',
      'energy-kcal',
    ]);
    if (energyKcal != null) {
      items.add(_ResolvedNutrient(
        label: 'Enerji',
        formattedValue: _formatAmount(energyKcal, isKcal: true),
        unit: 'kcal',
        accentColor: AppColors.cautionGold,
        icon: Icons.local_fire_department_rounded,
      ));
    }

    final double? fatG = _lookupValue(map, const <String>[
      'fat_g',
      'fat_100g',
      'fat',
    ]);
    if (fatG != null) {
      items.add(_ResolvedNutrient(
        label: 'Toplam Yağ',
        formattedValue: _formatAmount(fatG),
        unit: 'g',
        accentColor: fatG > 17.5 ? AppColors.cautionGold : AppColors.primaryMint,
        icon: Icons.water_drop_outlined,
      ));
    }

    final double? satFatG = _lookupValue(map, const <String>[
      'saturated_fat_g',
      'saturated-fat_100g',
      'saturated_fat_100g',
      'saturated-fat',
    ]);
    if (satFatG != null) {
      final Color satColor = satFatG > 5.0
          ? AppColors.dangerRed
          : (satFatG > 1.5 ? AppColors.cautionGold : AppColors.primaryEmerald);
      items.add(_ResolvedNutrient(
        label: 'Doymuş Yağ',
        formattedValue: _formatAmount(satFatG),
        unit: 'g',
        accentColor: satColor,
        icon: Icons.opacity_rounded,
      ));
    }

    final double? carbsG = _lookupValue(map, const <String>[
      'carbs_g',
      'carbohydrates_100g',
      'carbs_100g',
      'carbohydrates_g',
      'carbohydrates',
    ]);
    if (carbsG != null) {
      items.add(_ResolvedNutrient(
        label: 'Karbonhidrat',
        formattedValue: _formatAmount(carbsG),
        unit: 'g',
        accentColor: AppColors.primaryMint,
        icon: Icons.grain_rounded,
      ));
    }

    final double? sugarsG = _lookupValue(map, const <String>[
      'sugars_g',
      'sugars_100g',
      'sugar_g',
      'sugars',
    ]);
    if (sugarsG != null) {
      final Color sugarColor = sugarsG > 15.0
          ? AppColors.dangerRed
          : (sugarsG > 5.0 ? AppColors.cautionGold : AppColors.primaryEmerald);
      items.add(_ResolvedNutrient(
        label: 'Şekerler',
        formattedValue: _formatAmount(sugarsG),
        unit: 'g',
        accentColor: sugarColor,
        icon: Icons.icecream_outlined,
      ));
    }

    final double? fiberG = _lookupValue(map, const <String>[
      'fiber_g',
      'fiber_100g',
      'fiber',
    ]);
    if (fiberG != null) {
      items.add(_ResolvedNutrient(
        label: 'Diyet Lifi',
        formattedValue: _formatAmount(fiberG),
        unit: 'g',
        accentColor:
            fiberG >= 3.0 ? AppColors.primaryEmerald : AppColors.primaryMint,
        icon: Icons.eco_outlined,
      ));
    }

    final double? proteinG = _lookupValue(map, const <String>[
      'protein_g',
      'proteins_100g',
      'protein_100g',
      'proteins',
    ]);
    if (proteinG != null) {
      items.add(_ResolvedNutrient(
        label: 'Protein',
        formattedValue: _formatAmount(proteinG),
        unit: 'g',
        accentColor:
            proteinG >= 5.0 ? AppColors.primaryEmerald : AppColors.primaryMint,
        icon: Icons.fitness_center_rounded,
      ));
    }

    final double? directSaltG = _lookupValue(map, const <String>[
      'salt_g',
      'salt_100g',
      'salt',
    ]);
    final double? sodiumG = _lookupValue(map, const <String>[
      'sodium_g',
      'sodium_100g',
      'sodium',
    ]);
    final double? saltG =
        directSaltG ?? (sodiumG != null ? sodiumG * 2.5 : null);
    if (saltG != null) {
      final Color saltColor = saltG > 1.5
          ? AppColors.dangerRed
          : (saltG > 0.75 ? AppColors.cautionGold : AppColors.primaryEmerald);
      items.add(_ResolvedNutrient(
        label: 'Tuz',
        formattedValue: _formatAmount(saltG),
        unit: 'g',
        accentColor: saltColor,
        icon: Icons.scatter_plot_outlined,
      ));
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final List<String> cleanChains = _normalizeChains(marketChains);
    final String? cleanNetQty =
        (netQuantity != null && netQuantity!.trim().isNotEmpty)
            ? netQuantity!.trim()
            : null;
    final String? cleanProducer =
        (legalProducer != null && legalProducer!.trim().isNotEmpty)
            ? legalProducer!.trim()
            : null;
    final double? cleanPrice = (referencePriceTry != null &&
            referencePriceTry!.isFinite &&
            referencePriceTry! > 0)
        ? referencePriceTry
        : null;
    final List<String> cleanAllergens = _normalizeAllergens(allergens);
    final String cleanIngredients = ingredientsText.trim();
    final List<_ResolvedNutrient> resolvedNutrients =
        _resolveNutrients(nutriments);

    final bool hasMarketIdentity = cleanChains.isNotEmpty ||
        cleanNetQty != null ||
        cleanProducer != null ||
        cleanPrice != null;
    final bool hasAllergens = cleanAllergens.isNotEmpty;
    final bool hasIngredients = cleanIngredients.isNotEmpty;
    final bool hasNutrition = resolvedNutrients.isNotEmpty;

    if (!hasMarketIdentity &&
        !hasAllergens &&
        !hasIngredients &&
        !hasNutrition) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasMarketIdentity)
          _MarketIdentityCard(
            marketChains: cleanChains,
            netQuantity: cleanNetQty,
            legalProducer: cleanProducer,
            referencePriceTry: cleanPrice,
          ),
        if (hasAllergens)
          _AllergenWarningCard(
            allergens: cleanAllergens,
          ),
        if (hasIngredients)
          _TgkIngredientsCard(
            ingredientsText: cleanIngredients,
          ),
        if (hasNutrition)
          _NutritionFactsCard(
            nutrients: resolvedNutrients,
          ),
      ],
    );
  }
}

/// Displays verified Turkish supermarket availability badges, net weight/volume,
/// reference shelf price, and TGK legal food operator / producer identity.
class _MarketIdentityCard extends StatelessWidget {
  final List<String> marketChains;
  final String? netQuantity;
  final String? legalProducer;
  final double? referencePriceTry;

  const _MarketIdentityCard({
    required this.marketChains,
    this.netQuantity,
    this.legalProducer,
    this.referencePriceTry,
  });

  @override
  Widget build(BuildContext context) {
    final Color surfaceColor = context.surfaceColor;
    final Color borderColor = context.cardBorderColor;
    final Color textPrimary = context.textPrimaryColor;
    final bool hasPills = netQuantity != null || referencePriceTry != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.storefront_rounded,
                size: 18,
                color: AppColors.primaryEmerald,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Market Zincirleri & Ürün Kimliği',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (marketChains.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: marketChains
                  .map((String chain) => _MarketChainBadge(chainName: chain))
                  .toList(),
            ),
          ],
          if (hasPills) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (netQuantity != null)
                  _ProductMetaChip(
                    icon: Icons.scale_rounded,
                    label: 'Net Miktar: $netQuantity',
                    accentColor: AppColors.primaryMint,
                  ),
                if (referencePriceTry != null)
                  _ProductMetaChip(
                    icon: Icons.sell_outlined,
                    label: 'Ref. Fiyat: ₺${referencePriceTry!.toStringAsFixed(2)}',
                    accentColor: AppColors.primaryEmerald,
                  ),
              ],
            ),
          ],
          if (legalProducer != null) ...[
            const SizedBox(height: 10),
            _LegalProducerBanner(legalProducer: legalProducer!),
          ],
        ],
      ),
    );
  }
}

/// Atomic badge for national Turkish supermarket chains (`BİM`, `A101`, `ŞOK`, `Migros`, `CarrefourSA`, `Tarım Kredi`, `Hakmar`).
class _MarketChainBadge extends StatelessWidget {
  final String chainName;

  const _MarketChainBadge({required this.chainName});

  static Color _resolveChainAccent(String chain) {
    switch (chain.toLowerCase()) {
      case 'bim':
      case 'bım':
      case 'bi̇m':
        return const Color(0xFFE11D48);
      case 'a101':
        return const Color(0xFF0284C7);
      case 'şok':
      case 'sok':
        return const Color(0xFFD97706);
      case 'migros':
        return const Color(0xFFEA580C);
      case 'carrefoursa':
        return const Color(0xFF2563EB);
      case 'tarım kredi':
      case 'tarim kredi':
        return AppColors.primaryEmerald;
      case 'hakmar':
        return const Color(0xFF0D9488);
      default:
        return AppColors.primaryMint;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = _resolveChainAccent(chainName);
    final bool isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: accent.withValues(alpha: isDark ? 0.55 : 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            chainName,
            style: TextStyle(
              color: isDark ? Colors.white : accent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Atomic metadata pill for net quantity and reference market price.
class _ProductMetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accentColor;

  const _ProductMetaChip({
    required this.icon,
    required this.label,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color subtleBg = context.subtleSurfaceColor;
    final Color borderColor = context.cardBorderColor;
    final Color textPrimary = context.textPrimaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: subtleBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accentColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Atomic row displaying the verified TGK food business operator / legal manufacturer.
class _LegalProducerBanner extends StatelessWidget {
  final String legalProducer;

  const _LegalProducerBanner({required this.legalProducer});

  @override
  Widget build(BuildContext context) {
    final Color subtleBg = context.subtleSurfaceColor;
    final Color textSecondary = context.textSecondaryColor;
    final Color textPrimary = context.textPrimaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: subtleBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.verified_outlined,
              size: 15,
              color: AppColors.primaryMint,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: textSecondary,
                ),
                children: [
                  const TextSpan(
                    text: 'Gıda İşletmecisi / Üretici: ',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: legalProducer,
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Displays TGK allergen warnings as overflow-safe responsive chips.
class _AllergenWarningCard extends StatelessWidget {
  final List<String> allergens;

  const _AllergenWarningCard({required this.allergens});

  @override
  Widget build(BuildContext context) {
    final bool isDark = context.isDarkMode;
    final Color textPrimary = context.textPrimaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cautionGold.withValues(alpha: isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.cautionGold.withValues(alpha: 0.45),
        ),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: AppColors.cautionGold,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Alerjen Uyarısı (TGK)',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: allergens
                    .map(
                      (String item) => _AllergenChip(
                        label: item,
                        maxWidth: constraints.maxWidth,
                      ),
                    )
                    .toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Single overflow-safe allergen warning chip.
class _AllergenChip extends StatelessWidget {
  final String label;
  final double maxWidth;

  const _AllergenChip({
    required this.label,
    required this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = context.isDarkMode;
    final Color chipText =
        isDark ? AppColors.darkTextPrimary : const Color(0xFF92400E);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.cautionGold.withValues(alpha: isDark ? 0.22 : 0.14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.cautionGold.withValues(alpha: 0.55),
          ),
        ),
        child: Text(
          label,
          softWrap: true,
          style: TextStyle(
            color: chipText,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}

/// Displays the full, uninterrupted Turkish Food Codex (TGK) ingredients text without truncation.
class _TgkIngredientsCard extends StatelessWidget {
  final String ingredientsText;

  const _TgkIngredientsCard({required this.ingredientsText});

  @override
  Widget build(BuildContext context) {
    final Color surfaceColor = context.surfaceColor;
    final Color subtleBg = context.subtleSurfaceColor;
    final Color borderColor = context.cardBorderColor;
    final Color textPrimary = context.textPrimaryColor;
    final Color textSecondary = context.textSecondaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.description_outlined,
                size: 18,
                color: AppColors.primaryEmerald,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tam İçindekiler Beyanı (TGK)',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: subtleBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              ingredientsText,
              style: TextStyle(
                color: textSecondary,
                fontSize: 12.5,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Responsive, overflow-free 100g / 100ml nutrition facts grid card using `Wrap`.
class _NutritionFactsCard extends StatelessWidget {
  final List<_ResolvedNutrient> nutrients;

  const _NutritionFactsCard({required this.nutrients});

  @override
  Widget build(BuildContext context) {
    final Color surfaceColor = context.surfaceColor;
    final Color borderColor = context.cardBorderColor;
    final Color textPrimary = context.textPrimaryColor;
    final Color textSecondary = context.textSecondaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          const double spacing = 8.0;
          final bool useTwoColumns = constraints.maxWidth >= 260;
          final double tileWidth = useTwoColumns
              ? (constraints.maxWidth - spacing) / 2
              : constraints.maxWidth;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.analytics_outlined,
                    size: 18,
                    color: AppColors.primaryEmerald,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Besin Değerleri',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryEmerald.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '100g / 100ml',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: nutrients
                    .map(
                      (_ResolvedNutrient item) => _NutrientMetricTile(
                        nutrient: item,
                        width: tileWidth,
                      ),
                    )
                    .toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Atomic responsive tile for a single 100g/100ml nutrient metric.
class _NutrientMetricTile extends StatelessWidget {
  final _ResolvedNutrient nutrient;
  final double width;

  const _NutrientMetricTile({
    required this.nutrient,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final Color subtleBg = context.subtleSurfaceColor;
    final Color borderColor = context.cardBorderColor;
    final Color textPrimary = context.textPrimaryColor;
    final Color textSecondary = context.textSecondaryColor;

    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: subtleBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor.withValues(alpha: 0.7),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: nutrient.accentColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(
                nutrient.icon,
                size: 14,
                color: nutrient.accentColor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                nutrient.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${nutrient.formattedValue} ${nutrient.unit}',
              style: TextStyle(
                color: textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
