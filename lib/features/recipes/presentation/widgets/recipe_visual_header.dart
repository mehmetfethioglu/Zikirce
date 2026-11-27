import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/kilerce_logo_mark.dart';
import '../../data/recipe_image_disk_cache.dart';
import '../../domain/recipe_models.dart';

enum _VisualSourceMode {
  localFile,
  networkUrl,
  bundledAsset,
  gradientFallback,
}

/// Visual header banner for recipe cards and the recipe detail modal.
///
/// Priority order:
/// 1. User's custom local photo (`recipe.localImagePath`, non-web & file exists)
/// 2. Verified network photo (`recipe.imageUrl`)
/// 3. Bundled vector dish asset (`recipe.imageAsset`)
/// 4. Category-themed gradient artwork featuring the Kilerce brand emblem
class RecipeVisualHeader extends StatelessWidget {
  final KilerRecipe recipe;
  final double height;
  final bool compact;
  final int? combinedScore;
  final bool heroMode;
  final bool showOverlays;
  final BorderRadius? borderRadius;

  const RecipeVisualHeader({
    super.key,
    required this.recipe,
    this.height = 132,
    this.compact = false,
    this.combinedScore,
    this.heroMode = false,
    this.showOverlays = true,
    this.borderRadius,
  });

  _VisualSourceMode _resolveSourceMode() {
    final localPath = recipe.localImagePath?.trim();
    if (!kIsWeb &&
        localPath != null &&
        localPath.isNotEmpty &&
        File(localPath).existsSync()) {
      return _VisualSourceMode.localFile;
    }

    final url = recipe.imageUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return _VisualSourceMode.networkUrl;
    }

    final asset = recipe.imageAsset?.trim();
    if (asset != null && asset.isNotEmpty) {
      return _VisualSourceMode.bundledAsset;
    }

    return _VisualSourceMode.gradientFallback;
  }

  String? _sourceBadgeLabel(_VisualSourceMode mode) {
    switch (mode) {
      case _VisualSourceMode.localFile:
        return '📸 Gerçek Fotoğraf';
      case _VisualSourceMode.networkUrl:
        if (!heroMode) return null;
        final credit = recipe.photoCredit?.trim();
        return '📷 ${(credit != null && credit.isNotEmpty) ? credit : 'Temsili Görsel'}';
      case _VisualSourceMode.bundledAsset:
        return heroMode ? '✨ Kilerce Vektör Sunum' : null;
      case _VisualSourceMode.gradientFallback:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveRadius =
        borderRadius ?? BorderRadius.circular(heroMode ? 20 : 16);
    final regionMeta = TurkishRegionRegistry.findById(recipe.regionId);
    final categoryMeta = RecipeCategoryRegistry.findById(recipe.category);
    final palette = _CategoryPaletteRegistry.paletteFor(recipe.category);
    final sourceMode = _resolveSourceMode();
    final sourceBadge = _sourceBadgeLabel(sourceMode);

    return ClipRRect(
      borderRadius: effectiveRadius,
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _VisualBackdrop(
              recipe: recipe,
              sourceMode: sourceMode,
              palette: palette,
              compact: compact,
              heroMode: heroMode,
            ),
            const _ScrimOverlay(),
            if (showOverlays)
              _TopHeaderOverlay(
                categoryEmoji: categoryMeta?.emoji ?? recipe.emoji,
                categoryLabel: categoryMeta?.shortLabel ?? recipe.category,
                combinedScore: combinedScore,
                sourceBadgeLabel: sourceBadge,
                compact: compact,
                heroMode: heroMode,
              ),
            if (showOverlays && heroMode)
              _BottomMetaOverlay(
                originCity: recipe.originCity,
                regionShortLabel: regionMeta?.shortLabel,
                portionGram: recipe.portionGram,
                calories: recipe.calories,
                compact: compact,
                heroMode: heroMode,
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryPalette {
  final List<Color> colors;
  final Color accent;

  const _CategoryPalette({
    required this.colors,
    required this.accent,
  });
}

class _CategoryPaletteRegistry {
  static const _CategoryPalette _defaultPalette = _CategoryPalette(
    colors: [Color(0xFF0D281E), Color(0xFF1A4E3B), Color(0xFF2B7A5B)],
    accent: Color(0xFF34D399),
  );

  static const Map<String, _CategoryPalette> _palettes = {
    RecipeCategoryRegistry.breakfast: _CategoryPalette(
      colors: [Color(0xFF2A1A10), Color(0xFF6B3E18), Color(0xFFB56E29)],
      accent: Color(0xFFF59E0B),
    ),
    RecipeCategoryRegistry.soup: _CategoryPalette(
      colors: [Color(0xFF281611), Color(0xFF68321B), Color(0xFFA9552A)],
      accent: Color(0xFFFB923C),
    ),
    RecipeCategoryRegistry.meatFish: _CategoryPalette(
      colors: [Color(0xFF261217), Color(0xFF5D242E), Color(0xFF943D44)],
      accent: Color(0xFFF87171),
    ),
    RecipeCategoryRegistry.vegOliveOil: _CategoryPalette(
      colors: [Color(0xFF0D261C), Color(0xFF1A4F38), Color(0xFF2B7D57)],
      accent: Color(0xFF34D399),
    ),
    RecipeCategoryRegistry.legumesGrains: _CategoryPalette(
      colors: [Color(0xFF231B11), Color(0xFF543F22), Color(0xFF8A6836)],
      accent: Color(0xFFEAB308),
    ),
    RecipeCategoryRegistry.saladMeze: _CategoryPalette(
      colors: [Color(0xFF0B2520), Color(0xFF154E43), Color(0xFF237D6B)],
      accent: Color(0xFF2DD4BF),
    ),
    RecipeCategoryRegistry.healthyDessertKids: _CategoryPalette(
      colors: [Color(0xFF241628), Color(0xFF522D5B), Color(0xFF844D78)],
      accent: Color(0xFFE879F9),
    ),
  };

  static _CategoryPalette paletteFor(String category) {
    return _palettes[category] ?? _defaultPalette;
  }
}

class _VisualBackdrop extends StatelessWidget {
  final KilerRecipe recipe;
  final _VisualSourceMode sourceMode;
  final _CategoryPalette palette;
  final bool compact;
  final bool heroMode;

  const _VisualBackdrop({
    required this.recipe,
    required this.sourceMode,
    required this.palette,
    required this.compact,
    required this.heroMode,
  });

  @override
  Widget build(BuildContext context) {
    switch (sourceMode) {
      case _VisualSourceMode.localFile:
        return Image.file(
          File(recipe.localImagePath!.trim()),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _CategoryRegionFallbackArt(
            palette: palette,
            compact: compact,
            heroMode: heroMode,
          ),
        );
      case _VisualSourceMode.networkUrl:
        return _DiskCachedRecipeImage(
          imageUrl: recipe.imageUrl!.trim(),
          palette: palette,
          compact: compact,
          heroMode: heroMode,
        );
      case _VisualSourceMode.bundledAsset:
        return Image.asset(
          recipe.imageAsset!.trim(),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _CategoryRegionFallbackArt(
            palette: palette,
            compact: compact,
            heroMode: heroMode,
          ),
        );
      case _VisualSourceMode.gradientFallback:
        return _CategoryRegionFallbackArt(
          palette: palette,
          compact: compact,
          heroMode: heroMode,
        );
    }
  }
}

class _CategoryRegionFallbackArt extends StatelessWidget {
  final _CategoryPalette palette;
  final bool compact;
  final bool heroMode;

  const _CategoryRegionFallbackArt({
    required this.palette,
    required this.compact,
    required this.heroMode,
  });

  @override
  Widget build(BuildContext context) {
    final logoSize = heroMode ? 76.0 : (compact ? 44.0 : 56.0);
    final logoRadius = heroMode ? 22.0 : (compact ? 13.0 : 16.0);
    final haloSize = logoSize + (heroMode ? 10.0 : 6.0);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette.colors,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -24,
            top: -24,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.accent.withValues(alpha: 0.16),
              ),
            ),
          ),
          Positioned(
            left: -20,
            bottom: -30,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Center(
            child: Container(
              width: haloSize,
              height: haloSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(logoRadius + 3),
                border: Border.all(
                  color: palette.accent.withValues(alpha: 0.45),
                  width: 1.5,
                ),
              ),
              child: KilerceLogoMark(
                size: logoSize,
                borderRadius: logoRadius,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScrimOverlay extends StatelessWidget {
  const _ScrimOverlay();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x52000000),
            Color(0x00000000),
            Color(0xA6050B09),
          ],
          stops: [0.0, 0.45, 1.0],
        ),
      ),
    );
  }
}

class _TopHeaderOverlay extends StatelessWidget {
  final String categoryEmoji;
  final String categoryLabel;
  final int? combinedScore;
  final String? sourceBadgeLabel;
  final bool compact;
  final bool heroMode;

  const _TopHeaderOverlay({
    required this.categoryEmoji,
    required this.categoryLabel,
    required this.combinedScore,
    required this.sourceBadgeLabel,
    required this.compact,
    required this.heroMode,
  });

  @override
  Widget build(BuildContext context) {
    final inset = heroMode ? 12.0 : 9.0;
    return Positioned(
      top: inset,
      left: inset,
      right: inset,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: _GlassMetaBadge(
                  label: '$categoryEmoji $categoryLabel',
                  compact: compact,
                ),
              ),
              if (combinedScore != null) ...[
                const SizedBox(width: 6),
                _HealthScoreOverlayBadge(
                  score: combinedScore!,
                  compact: compact,
                ),
              ],
            ],
          ),
          if (sourceBadgeLabel != null) ...[
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.centerLeft,
              child: _GlassMetaBadge(
                label: sourceBadgeLabel!,
                compact: true,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BottomMetaOverlay extends StatelessWidget {
  final String originCity;
  final String? regionShortLabel;
  final int portionGram;
  final int calories;
  final bool compact;
  final bool heroMode;

  const _BottomMetaOverlay({
    required this.originCity,
    required this.regionShortLabel,
    required this.portionGram,
    required this.calories,
    required this.compact,
    required this.heroMode,
  });

  @override
  Widget build(BuildContext context) {
    final inset = heroMode ? 12.0 : 9.0;
    final originLabel = regionShortLabel != null && regionShortLabel!.isNotEmpty
        ? '📍 $originCity • $regionShortLabel'
        : '📍 $originCity';

    return Positioned(
      bottom: inset,
      left: inset,
      right: inset,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: _GlassMetaBadge(
              label: originLabel,
              compact: compact,
            ),
          ),
          const SizedBox(width: 6),
          _GlassMetaBadge(
            label: '1 Porsiyon ($portionGram g) • $calories kcal',
            compact: compact,
          ),
        ],
      ),
    );
  }
}

class _GlassMetaBadge extends StatelessWidget {
  final String label;
  final bool compact;

  const _GlassMetaBadge({
    required this.label,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 8.5,
        vertical: compact ? 3 : 4.5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xB8091410),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white,
          fontSize: compact ? 9.5 : 10.2,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

class _HealthScoreOverlayBadge extends StatelessWidget {
  final int score;
  final bool compact;

  const _HealthScoreOverlayBadge({
    required this.score,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = score >= 85
        ? AppColors.primaryEmerald
        : score >= 70
            ? AppColors.cautionGold
            : AppColors.dangerRed;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 3 : 4.5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xCC07110D),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: accentColor.withValues(alpha: 0.8)),
      ),
      child: Text(
        'Skor $score',
        style: TextStyle(
          color: accentColor,
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DiskCachedRecipeImage extends StatefulWidget {
  final String imageUrl;
  final _CategoryPalette palette;
  final bool compact;
  final bool heroMode;

  const _DiskCachedRecipeImage({
    required this.imageUrl,
    required this.palette,
    required this.compact,
    required this.heroMode,
  });

  @override
  State<_DiskCachedRecipeImage> createState() => _DiskCachedRecipeImageState();
}

class _DiskCachedRecipeImageState extends State<_DiskCachedRecipeImage> {
  File? _cachedFile;

  @override
  void initState() {
    super.initState();
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant _DiskCachedRecipeImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (RecipeImageDiskCache.canonicalCacheKey(oldWidget.imageUrl) !=
        RecipeImageDiskCache.canonicalCacheKey(widget.imageUrl)) {
      _cachedFile = null;
      _resolveImage();
    }
  }

  Future<void> _resolveImage() async {
    if (kIsWeb) return;
    final file = await RecipeImageDiskCache.instance.getOrFetchFile(widget.imageUrl);
    if (!mounted) return;
    if (file != null) {
      setState(() {
        _cachedFile = file;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Image.network(
        widget.imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _CategoryRegionFallbackArt(
          palette: widget.palette,
          compact: widget.compact,
          heroMode: widget.heroMode,
        ),
      );
    }

    if (_cachedFile != null) {
      return Image.file(
        _cachedFile!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _CategoryRegionFallbackArt(
          palette: widget.palette,
          compact: widget.compact,
          heroMode: widget.heroMode,
        ),
      );
    }

    return _CategoryRegionFallbackArt(
      palette: widget.palette,
      compact: widget.compact,
      heroMode: widget.heroMode,
    );
  }
}
