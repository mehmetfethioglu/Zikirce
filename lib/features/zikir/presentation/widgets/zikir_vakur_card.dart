import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/zikir_seed_data.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/utils/quran_word_highlighter.dart';
import 'add_edit_zikir_sheet.dart';

/// Shared pure layout & filtering helpers for [ZikirVakurCard] views.
class ZikirCardStyleHelper {
  const ZikirCardStyleHelper._();

  static List<String> getCategories(AppLocalizations l10n) => [
        l10n.translate('ZikirList_CatAll'),
        l10n.translate('ZikirList_CatFavorites'),
        l10n.translate('ZikirList_CatHadith'),
        l10n.translate('ZikirList_CatEsma'),
        l10n.translate('ZikirList_CatDuas'),
        l10n.translate('ZikirList_CatCustom'),
      ];

  static List<Zikir> filterAndSort({
    required List<Zikir> zikirs,
    required int selectedCategoryIndex,
    required String searchQuery,
  }) {
    final q = searchQuery.trim().toLowerCase();
    return ZikirSeedData.sortBySeedOrder(
      zikirs.where((z) {
        final lowerCat = z.category.toLowerCase();
        final matchesCat = selectedCategoryIndex == 0 ||
            (selectedCategoryIndex == 1 && z.isFavorite) ||
            (selectedCategoryIndex == 2 &&
                (lowerCat.contains('hadis') || lowerCat.contains('hadith'))) ||
            (selectedCategoryIndex == 3 &&
                (lowerCat.contains('esma') || lowerCat.contains('asma'))) ||
            (selectedCategoryIndex == 4 &&
                (lowerCat.contains('dua') || lowerCat.contains('prayer'))) ||
            (selectedCategoryIndex == 5 &&
                (lowerCat.contains('özel') || lowerCat.contains('custom')));
        final matchesQuery = q.isEmpty ||
            z.name.toLowerCase().contains(q) ||
            (z.arabic != null && z.arabic!.contains(q));
        return matchesCat && matchesQuery;
      }).toList(),
    );
  }

  static double resolveArabicFontSize(String arabicText, bool isExpanded) {
    final len = arabicText.trim().length;
    final double baseSize;
    if (len <= 22) {
      baseSize = 42.0;
    } else if (len <= 48) {
      baseSize = 36.0;
    } else if (len <= 95) {
      baseSize = 30.0;
    } else if (len <= 160) {
      baseSize = 25.0;
    } else {
      baseSize = 22.0;
    }
    return isExpanded ? (baseSize * 0.82).clamp(20.0, 32.0) : baseSize;
  }

  static String getVirtueSectionTitle(String category, AppLocalizations l10n) {
    final lowerCat = category.toLowerCase();
    final isDuaCat = lowerCat.contains('dua') || lowerCat.contains('prayer');
    final isEsmaCat = lowerCat.contains('esma') || lowerCat.contains('asma');
    if (l10n.isTurkish) {
      if (isDuaCat) return 'Âyet Meâli & Kaynak';
      if (isEsmaCat) return 'İsmin Mânâsı & Fazileti';
      return 'Sahih Hadis-i Şerif & Fazileti';
    }
    if (isDuaCat) return 'Verse Meaning & Source';
    if (isEsmaCat) return 'Meaning & Virtues';
    return 'Authentic Hadith & Virtues';
  }
}

/// Dignified single-responsibility Dhikr Card widget shared across ZikirListScreen & ZikirSelectionSheet.
class ZikirVakurCard extends StatelessWidget {
  final Zikir zikir;
  final int index;
  final bool isCurrentCard;
  final bool isExpanded;
  final bool isActiveSelected;
  final bool isDark;
  final String arabicFontFamily;
  final bool isBoldArabic;
  final bool highlightDivine;
  final double arabicFontSize;
  final String virtueTitle;
  final String? primaryActionLabel;
  final IconData? primaryActionIcon;
  final VoidCallback onToggleExpand;
  final VoidCallback onToggleFavorite;
  final Future<void> Function(Insertable<Zikir>) onSaveEdit;
  final Future<void> Function() onResetCount;
  final Future<void> Function() onDelete;
  final VoidCallback onStartZikir;

  const ZikirVakurCard({
    super.key,
    required this.zikir,
    required this.index,
    required this.isCurrentCard,
    required this.isExpanded,
    required this.isActiveSelected,
    required this.isDark,
    required this.arabicFontFamily,
    required this.isBoldArabic,
    required this.highlightDivine,
    required this.arabicFontSize,
    required this.virtueTitle,
    this.primaryActionLabel,
    this.primaryActionIcon,
    required this.onToggleExpand,
    required this.onToggleFavorite,
    required this.onSaveEdit,
    required this.onResetCount,
    required this.onDelete,
    required this.onStartZikir,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final cardBg = colors.cardBackground;
    final primaryTextColor = colors.primaryText;
    final secondaryTextColor = colors.secondaryTextAlt;
    final accentColor = colors.accent;
    final borderStroke = colors.borderStroke;

    final progress =
        (zikir.currentCount / (zikir.target > 0 ? zikir.target : 1)).clamp(0.0, 1.0);
    final virtue = ZikirSeedData.getVirtueForZikir(zikir.name, arabic: zikir.arabic);
    final resolvedVirtueText = (virtue != null && virtue.trim().isNotEmpty)
        ? virtue
        : (l10n.isTurkish
            ? '${zikir.name} (${zikir.category}) — Günlük hedef: ${zikir.target} adet.'
            : '${zikir.name} (${zikir.category}) — Target: ${zikir.target}.');
    final hasArabic = zikir.arabic != null && zikir.arabic!.trim().isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 330;
        final isUltraCompact = constraints.maxHeight < 275;
        final effectiveArabicSize =
            isCompact ? (arabicFontSize * 0.80).clamp(18.0, 30.0) : arabicFontSize;

        final cardBody = Column(
          mainAxisSize: isUltraCompact ? MainAxisSize.min : MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Minimalist Top Row: Metadata + Favorite + Actions
            Row(
              children: [
                if (isActiveSelected) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  '${(index + 1).toString().padLeft(2, '0')}  ·  ',
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
                Expanded(
                  child: Text(
                    zikir.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: secondaryTextColor,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                InkWell(
                  onTap: onToggleFavorite,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: Icon(
                      zikir.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: zikir.isFavorite
                          ? const Color(0xFFD97706)
                          : colors.tertiaryText,
                      size: 21,
                    ),
                  ),
                ),
                ZikirActionMenu(
                  zikir: zikir,
                  onSaveEdit: onSaveEdit,
                  onResetCount: onResetCount,
                  onDelete: onDelete,
                ),
              ],
            ),

            SizedBox(height: isCompact ? 6 : 12),

            // 2. Dignified Title
            Text(
              zikir.name,
              textAlign: TextAlign.center,
              maxLines: isCompact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isCompact ? 16 : 18,
                fontWeight: FontWeight.w700,
                color: primaryTextColor,
                letterSpacing: -0.2,
                height: 1.25,
              ),
            ),

            if (!isCompact) ...[
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 32,
                  height: 1,
                  color: borderStroke,
                ),
              ),
            ],

            // 3. Centerpiece: Pure Arabic Calligraphy & Expandable Virtue
            if (isUltraCompact) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: _buildArabicCalligraphy(
                  colors: colors,
                  hasArabic: hasArabic,
                  fontSize: effectiveArabicSize,
                ),
              ),
              if (isExpanded) ...[
                Divider(
                  height: 12,
                  thickness: 0.7,
                  color: borderStroke.withValues(alpha: 0.7),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        virtueTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_up_rounded,
                      size: 16,
                      color: colors.tertiaryText,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  resolvedVirtueText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: secondaryTextColor,
                  ),
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: _buildCollapsedVirtueHint(l10n, colors),
                ),
            ] else
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      flex: isExpanded ? 5 : 8,
                      child: Center(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: isCompact ? 6 : 12,
                          ),
                          child: _buildArabicCalligraphy(
                            colors: colors,
                            hasArabic: hasArabic,
                            fontSize: effectiveArabicSize,
                          ),
                        ),
                      ),
                    ),
                    if (isExpanded)
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Divider(
                              height: isCompact ? 10 : 16,
                              thickness: 0.7,
                              color: borderStroke.withValues(alpha: 0.7),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    virtueTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: accentColor,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.keyboard_arrow_up_rounded,
                                  size: 16,
                                  color: colors.tertiaryText,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Expanded(
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: Text(
                                  resolvedVirtueText,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13.0,
                                    height: 1.5,
                                    color: secondaryTextColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: _buildCollapsedVirtueHint(l10n, colors),
                      ),
                  ],
                ),
              ),

            SizedBox(height: isCompact ? 8 : 12),

            // 4. Delicate Progress Hairline
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 2.5,
                backgroundColor: borderStroke.withValues(alpha: 0.5),
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              ),
            ),

            SizedBox(height: isCompact ? 8 : 14),

            // 5. Unified Clean Footer: Counter Stats + Dignified Start Action
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '${zikir.currentCount}',
                              style: TextStyle(
                                fontSize: isCompact ? 14.5 : 16,
                                fontWeight: FontWeight.w700,
                                color: primaryTextColor,
                              ),
                            ),
                            TextSpan(
                              text: ' / ${zikir.target}',
                              style: TextStyle(
                                fontSize: isCompact ? 12 : 13,
                                fontWeight: FontWeight.w500,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${l10n.zikirPageTotal}: ${zikir.totalCount}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: colors.tertiaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onStartZikir,
                  style: TextButton.styleFrom(
                    backgroundColor: isActiveSelected
                        ? accentColor
                        : accentColor.withValues(alpha: 0.12),
                    foregroundColor: isActiveSelected ? Colors.white : accentColor,
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 14 : 18,
                      vertical: isCompact ? 8 : 11,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: Icon(
                    primaryActionIcon ?? Icons.fingerprint_rounded,
                    size: 18,
                  ),
                  label: Text(
                    primaryActionLabel ??
                        (l10n.isTurkish ? 'Zikre Başla' : 'Start Dhikr'),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );

        return AnimatedScale(
          scale: isCurrentCard ? 1.0 : 0.95,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: isCurrentCard ? 1.0 : 0.55,
            duration: const Duration(milliseconds: 260),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 6,
                vertical: isCompact ? 4 : 8,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onToggleExpand,
                  borderRadius: BorderRadius.circular(24),
                  splashColor: accentColor.withValues(alpha: 0.05),
                  highlightColor: accentColor.withValues(alpha: 0.03),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    padding: EdgeInsets.fromLTRB(
                      isCompact ? 18 : 24,
                      isCompact ? 12 : 20,
                      isCompact ? 16 : 20,
                      isCompact ? 12 : 20,
                    ),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isActiveSelected
                            ? accentColor.withValues(alpha: 0.65)
                            : borderStroke.withValues(alpha: isDark ? 0.6 : 0.85),
                        width: isActiveSelected ? 1.5 : 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.04),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: isUltraCompact
                        ? SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: cardBody,
                          )
                        : cardBody,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCollapsedVirtueHint(AppLocalizations l10n, AppThemeColors colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            l10n.isTurkish ? 'Fazileti ve mânâsı' : 'Meaning & virtues',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: colors.tertiaryText,
              letterSpacing: 0.2,
            ),
          ),
        ),
        const SizedBox(width: 2),
        Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 15,
          color: colors.tertiaryText,
        ),
      ],
    );
  }

  Widget _buildArabicCalligraphy({
    required AppThemeColors colors,
    required bool hasArabic,
    required double fontSize,
  }) {
    if (!hasArabic) {
      return Text(
        zikir.name,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: colors.zikirArabicColor,
        ),
      );
    }
    return Text.rich(
      TextSpan(
        children: QuranWordHighlighter.buildHighlightedSpans(
          rawText: zikir.arabic!,
          baseStyle: TextStyle(
            fontFamily: arabicFontFamily,
            fontSize: fontSize,
            fontWeight: isBoldArabic ? FontWeight.bold : FontWeight.normal,
            height: 1.75,
            color: colors.zikirArabicColor,
          ),
          isDark: isDark,
          enabled: highlightDivine,
          fontFamily: arabicFontFamily,
          isBold: isBoldArabic,
        ),
      ),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
    );
  }
}

/// Overflow menu for individual [ZikirVakurCard] actions (Transfer, Edit, Reset, Delete).
class ZikirActionMenu extends StatelessWidget {
  final Zikir zikir;
  final Future<void> Function(Insertable<Zikir>) onSaveEdit;
  final Future<void> Function() onResetCount;
  final Future<void> Function() onDelete;

  const ZikirActionMenu({
    super.key,
    required this.zikir,
    required this.onSaveEdit,
    required this.onResetCount,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final cardBg = colors.cardBackground;
    final primaryTextColor = colors.primaryText;
    final secondaryTextColor = colors.secondaryTextAlt;
    final accentColor = colors.accent;
    final borderStroke = colors.borderStroke;

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz_rounded, size: 20, color: colors.tertiaryText),
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: borderStroke),
      ),
      onSelected: (action) async {
        HapticService.selectionClick();
        if (action == 'transfer') {
          await AddEditZikirSheet.show(
            context,
            zikir: zikir,
            initialTabIndex: 1,
          );
        } else if (action == 'edit') {
          await AddEditZikirSheet.show(
            context,
            zikir: zikir,
            initialTabIndex: 0,
            onSave: onSaveEdit,
          );
        } else if (action == 'reset') {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Text(l10n.zikirPageReset, style: TextStyle(color: primaryTextColor)),
              content: Text(
                l10n.isTurkish
                    ? "'${zikir.name}' sayacını sıfırlamak istiyor musunuz?"
                    : "Do you want to reset the counter for '${zikir.name}'?",
                style: TextStyle(color: secondaryTextColor),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(l10n.commonCancel, style: TextStyle(color: secondaryTextColor)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(l10n.zikirPageReset),
                ),
              ],
            ),
          );
          if (confirm == true) {
            await onResetCount();
          }
        } else if (action == 'delete') {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Text(l10n.commonDelete, style: TextStyle(color: primaryTextColor)),
              content: Text(
                l10n.isTurkish
                    ? "'${zikir.name}' zikrini silmek istediğinize emin misiniz?"
                    : "Are you sure you want to delete '${zikir.name}'?",
                style: TextStyle(color: secondaryTextColor),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(l10n.commonCancel, style: TextStyle(color: secondaryTextColor)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(l10n.commonDelete),
                ),
              ],
            ),
          );
          if (confirm == true) {
            await onDelete();
          }
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'transfer',
          child: Row(
            children: [
              Icon(Icons.archive_outlined, size: 18, color: accentColor),
              const SizedBox(width: 10),
              Text(l10n.addZikirImportTitle, style: TextStyle(color: primaryTextColor, fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 18, color: colors.secondaryText),
              const SizedBox(width: 10),
              Text(l10n.commonEdit, style: TextStyle(color: primaryTextColor, fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'reset',
          child: Row(
            children: [
              Icon(Icons.replay_rounded, size: 18, color: Colors.orange.shade700),
              const SizedBox(width: 10),
              Text(l10n.zikirPageReset, style: TextStyle(color: primaryTextColor, fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red.shade700),
              const SizedBox(width: 10),
              Text(l10n.commonDelete, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}
