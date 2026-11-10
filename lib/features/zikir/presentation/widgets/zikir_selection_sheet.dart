import 'dart:async';
import 'dart:ui';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/zikir_seed_data.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../kuran/providers/kuran_providers.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../providers/zikir_providers.dart';
import 'add_edit_zikir_sheet.dart';
import 'zikir_vakur_card.dart';

/// Card-based Dhikr Selection BottomSheet for ZikirCounterScreen with
/// "Add New Dhikr" & "Import from Tasbeeh" actions, search, and category filters.
class ZikirSelectionSheet extends ConsumerStatefulWidget {
  final FutureOr<void> Function()? onBeforeSelectZikir;

  const ZikirSelectionSheet({
    super.key,
    this.onBeforeSelectZikir,
  });

  static Future<void> show(
    BuildContext context, {
    FutureOr<void> Function()? onBeforeSelectZikir,
  }) {
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ZikirSelectionSheet(
        onBeforeSelectZikir: onBeforeSelectZikir,
      ),
    );
  }

  @override
  ConsumerState<ZikirSelectionSheet> createState() => _ZikirSelectionSheetState();
}

class _ZikirSelectionSheetState extends ConsumerState<ZikirSelectionSheet> {
  int _selectedCategoryIndex = 0;
  String _searchQuery = '';
  int _currentPage = 0;
  bool _didAlignInitialZikir = false;
  int? _pendingFocusZikirId;
  final Set<int> _expandedZikirIds = <int>{};

  final TextEditingController _searchController = TextEditingController();
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    final initialList = ref.read(zikirListStreamProvider).valueOrNull;
    final selectedId = ref.read(selectedZikirIdProvider);
    int initialIndex = 0;
    if (initialList != null && initialList.isNotEmpty && selectedId != null) {
      final sorted = ZikirSeedData.sortBySeedOrder(initialList);
      final foundIdx = sorted.indexWhere((z) => z.id == selectedId);
      if (foundIdx >= 0) {
        initialIndex = foundIdx;
        _didAlignInitialZikir = true;
      }
    }
    _currentPage = initialIndex;
    _pageController = PageController(
      viewportFraction: 0.90,
      initialPage: initialIndex,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _resetCarouselToFirstPage() {
    _currentPage = 0;
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  void _goToPage(int targetPage, int maxLength) {
    if (maxLength <= 0) return;
    final clamped = targetPage.clamp(0, maxLength - 1);
    if (clamped == _currentPage) return;
    HapticService.selectionClick();
    setState(() => _currentPage = clamped);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        clamped,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _toggleExplanation(int zikirId) {
    HapticService.selectionClick();
    setState(() {
      if (_expandedZikirIds.contains(zikirId)) {
        _expandedZikirIds.remove(zikirId);
      } else {
        _expandedZikirIds.add(zikirId);
      }
    });
  }

  Future<void> _saveNewZikir(Insertable<Zikir> comp) async {
    await widget.onBeforeSelectZikir?.call();
    final newId = await ref.read(zikirCrudProvider).insertZikir(comp);
    await ref.read(selectedZikirIdProvider.notifier).select(newId);
    if (mounted) {
      setState(() {
        _selectedCategoryIndex = 0;
        _searchQuery = '';
        _searchController.clear();
        _pendingFocusZikirId = newId;
      });
    }
  }

  Future<void> _modifyZikir(
    int zikirId,
    Insertable<Zikir> comp,
    AppLocalizations l10n, {
    bool rethrowOnError = false,
  }) async {
    try {
      await ref.read(zikirCrudProvider).updateZikir(zikirId, comp);
    } catch (e) {
      debugPrint('[ZikirSelectionSheet] Zikir güncelleme hatası: $e');
      if (rethrowOnError) rethrow;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.isTurkish ? 'Güncellenemedi: $e' : 'Update failed: $e',
            ),
          ),
        );
      }
    }
  }

  Future<void> _removeZikir(
    int zikirId,
    AppLocalizations l10n,
  ) async {
    try {
      await ref.read(zikirCrudProvider).deleteZikir(zikirId);
      if (mounted && _currentPage > 0) {
        setState(() => _currentPage = _currentPage - 1);
      }
    } catch (e) {
      debugPrint('[ZikirSelectionSheet] Zikir silme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.isTurkish ? 'Silinemedi: $e' : 'Delete failed: $e',
            ),
          ),
        );
      }
    }
  }

  void _alignCarouselIfNeeded(List<Zikir> filtered, int? selectedZikirId) {
    final targetId = _pendingFocusZikirId ??
        (!_didAlignInitialZikir ? selectedZikirId : null);
    if (targetId == null || filtered.isEmpty) return;

    final idx = filtered.indexWhere((z) => z.id == targetId);
    if (idx < 0) return;

    _didAlignInitialZikir = true;
    _pendingFocusZikirId = null;
    if (idx == _currentPage) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _currentPage = idx);
      if (_pageController.hasClients) {
        _pageController.jumpToPage(idx);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final isFocusMode = ref.watch(isZikirFocusModeProvider.select((v) => v));
    final isDark = Theme.of(context).brightness == Brightness.dark || isFocusMode;

    final zikirsAsync = ref.watch(zikirListStreamProvider);
    final arabicFontFamily = ref.watch(arabicFontFamilyProvider.select((v) => v));
    final isBoldArabic = ref.watch(isBoldArabicProvider.select((v) => v));
    final highlightDivine = ref.watch(highlightDivineWordsProvider.select((v) => v));
    final selectedZikirId = ref.watch(selectedZikirIdProvider.select((v) => v));
    final categories = ZikirCardStyleHelper.getCategories(l10n);

    final mediaQuery = MediaQuery.of(context);
    final maxAvailableHeight =
        (mediaQuery.size.height - mediaQuery.padding.top - 12).clamp(220.0, 780.0);
    final sheetHeight =
        (mediaQuery.size.height * 0.86).clamp(220.0, maxAvailableHeight);
    final isKeyboardOpen = mediaQuery.viewInsets.bottom > 40;

    final allZikirs = zikirsAsync.valueOrNull ?? const <Zikir>[];
    final filteredSnapshot = ZikirCardStyleHelper.filterAndSort(
      zikirs: allZikirs,
      selectedCategoryIndex: _selectedCategoryIndex,
      searchQuery: _searchQuery,
    );
    final activeCardZikir = filteredSnapshot.isNotEmpty
        ? filteredSnapshot[_currentPage.clamp(0, filteredSnapshot.length - 1)]
        : ref.read(currentZikirProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: sheetHeight),
        child: Container(
          height: sheetHeight,
          padding: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F1A17) : colors.bottomSheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: colors.borderStroke, width: 1.2),
            ),
          ),
          child: SafeArea(
            top: false,
            bottom: !isKeyboardOpen,
            child: Column(
              children: [
                // 1. Drag Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                SizedBox(height: isKeyboardOpen ? 6 : 10),

                // 2. Title & Close Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.isTurkish ? 'Zikir Seçin' : 'Select Dhikr',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isKeyboardOpen ? 17 : 19,
                            fontWeight: FontWeight.bold,
                            color: colors.primaryText,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: colors.cardBackground,
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.borderStroke),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: colors.secondaryTextAlt,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isKeyboardOpen ? 6 : 10),

                // 3. Action Buttons Row: Yeni Zikir Ekle & Zikirmatikten Aktar
                if (!isKeyboardOpen) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _SheetActionButton(
                            icon: Icons.add_circle_outline_rounded,
                            label: l10n.addZikirNewTitle,
                            colors: colors,
                            isPrimary: true,
                            onTap: () {
                              HapticService.selectionClick();
                              AddEditZikirSheet.show(
                                context,
                                initialTabIndex: 0,
                                onSave: _saveNewZikir,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _SheetActionButton(
                            icon: Icons.archive_outlined,
                            label: l10n.addZikirImportTitle,
                            colors: colors,
                            isPrimary: false,
                            onTap: () async {
                              HapticService.selectionClick();
                              if (activeCardZikir != null) {
                                await ref
                                    .read(
                                        zikirCounterNotifierProvider(activeCardZikir.id)
                                            .notifier)
                                    .flushPending();
                              }
                              if (!context.mounted) return;
                              await AddEditZikirSheet.show(
                                context,
                                zikir: activeCardZikir,
                                initialTabIndex: 1,
                                onSave: _saveNewZikir,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // 4. Search Input
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.cardBackground,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: colors.borderStroke.withValues(alpha: 0.7),
                        width: 0.8,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: colors.secondaryTextAlt,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val.trim().toLowerCase();
                                _resetCarouselToFirstPage();
                              });
                            },
                            style: TextStyle(color: colors.primaryText, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: l10n.zikirListSearchHint,
                              hintStyle: TextStyle(
                                color: colors.tertiaryText,
                                fontSize: 12,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          InkWell(
                            onTap: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _resetCarouselToFirstPage();
                              });
                            },
                            child: Icon(
                              Icons.clear_rounded,
                              size: 16,
                              color: colors.secondaryTextAlt,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),

                // 5. Category Chips
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, idx) {
                      final cat = categories[idx];
                      final isSelected = _selectedCategoryIndex == idx;
                      return ChoiceChip(
                        label: Text(
                          cat,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? Colors.white : colors.secondaryTextAlt,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: colors.accent,
                        backgroundColor: colors.cardBackground,
                        visualDensity: VisualDensity.compact,
                        side: BorderSide(
                          color: isSelected
                              ? colors.accent
                              : colors.borderStroke.withValues(alpha: 0.6),
                          width: 0.8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        onSelected: (_) {
                          if (_selectedCategoryIndex == idx) return;
                          HapticService.selectionClick();
                          setState(() {
                            _selectedCategoryIndex = idx;
                            _resetCarouselToFirstPage();
                          });
                        },
                      );
                    },
                  ),
                ),

                // 6. Zikir Cards Carousel + Page Indicator
                Expanded(
                  child: zikirsAsync.when(
                    data: (zikirs) {
                      final filtered = ZikirCardStyleHelper.filterAndSort(
                        zikirs: zikirs,
                        selectedCategoryIndex: _selectedCategoryIndex,
                        searchQuery: _searchQuery,
                      );

                      if (filtered.isEmpty) {
                        return Center(
                          child: Text(
                            l10n.isTurkish ? 'Kayıt bulunamadı' : 'No records found',
                            style: TextStyle(color: colors.secondaryTextAlt),
                          ),
                        );
                      }

                      _alignCarouselIfNeeded(filtered, selectedZikirId);
                      final safePage = _currentPage.clamp(0, filtered.length - 1);

                      return Column(
                        children: [
                          Expanded(
                            child: ScrollConfiguration(
                              behavior: ScrollConfiguration.of(context).copyWith(
                                dragDevices: {
                                  PointerDeviceKind.touch,
                                  PointerDeviceKind.mouse,
                                  PointerDeviceKind.trackpad,
                                },
                              ),
                              child: PageView.builder(
                                controller: _pageController,
                                physics: const BouncingScrollPhysics(),
                                itemCount: filtered.length,
                                onPageChanged: (idx) {
                                  HapticService.selectionClick();
                                  setState(() => _currentPage = idx);
                                },
                                itemBuilder: (context, index) {
                                  final zikir = filtered[index];
                                  final isCurrentCard = index == safePage;
                                  final isExpanded = _expandedZikirIds.contains(zikir.id);
                                  final isActiveSelected = zikir.id == selectedZikirId;

                                  return ZikirVakurCard(
                                    zikir: zikir,
                                    index: index,
                                    isCurrentCard: isCurrentCard,
                                    isExpanded: isExpanded,
                                    isActiveSelected: isActiveSelected,
                                    isDark: isDark,
                                    arabicFontFamily: arabicFontFamily,
                                    isBoldArabic: isBoldArabic,
                                    highlightDivine: highlightDivine,
                                    arabicFontSize:
                                        ZikirCardStyleHelper.resolveArabicFontSize(
                                      zikir.arabic ?? '',
                                      isExpanded,
                                    ),
                                    virtueTitle:
                                        ZikirCardStyleHelper.getVirtueSectionTitle(
                                      zikir.category,
                                      l10n,
                                    ),
                                    primaryActionIcon: isActiveSelected
                                        ? Icons.check_circle_outline_rounded
                                        : Icons.fingerprint_rounded,
                                    primaryActionLabel: isActiveSelected
                                        ? (l10n.isTurkish ? 'Devam Et' : 'Continue')
                                        : (l10n.isTurkish ? 'Zikre Başla' : 'Start Dhikr'),
                                    onToggleExpand: () => _toggleExplanation(zikir.id),
                                    onToggleFavorite: () {
                                      HapticService.selectionClick();
                                      _modifyZikir(
                                        zikir.id,
                                        ZikirsCompanion(
                                          isFavorite: Value(!zikir.isFavorite),
                                        ),
                                        l10n,
                                      );
                                    },
                                    onSaveEdit: (comp) => _modifyZikir(
                                      zikir.id,
                                      comp,
                                      l10n,
                                      rethrowOnError: true,
                                    ),
                                    onResetCount: () => _modifyZikir(
                                      zikir.id,
                                      const ZikirsCompanion(
                                        currentCount: Value(0),
                                        lap: Value(0),
                                      ),
                                      l10n,
                                    ),
                                    onDelete: () => _removeZikir(zikir.id, l10n),
                                    onStartZikir: () async {
                                      HapticService.selectionClick();
                                      await widget.onBeforeSelectZikir?.call();
                                      await ref
                                          .read(selectedZikirIdProvider.notifier)
                                          .select(zikir.id);
                                      if (context.mounted) {
                                        Navigator.of(context).pop();
                                      }
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                          if (!isKeyboardOpen)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(28, 0, 28, 6),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    onPressed: safePage > 0
                                        ? () => _goToPage(safePage - 1, filtered.length)
                                        : null,
                                    visualDensity: VisualDensity.compact,
                                    icon: Icon(
                                      Icons.chevron_left_rounded,
                                      size: 22,
                                      color: safePage > 0
                                          ? colors.secondaryTextAlt
                                          : colors.tertiaryText.withValues(alpha: 0.35),
                                    ),
                                  ),
                                  Text(
                                    '${safePage + 1} / ${filtered.length}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.0,
                                      color: colors.secondaryTextAlt,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: safePage < filtered.length - 1
                                        ? () => _goToPage(safePage + 1, filtered.length)
                                        : null,
                                    visualDensity: VisualDensity.compact,
                                    icon: Icon(
                                      Icons.chevron_right_rounded,
                                      size: 22,
                                      color: safePage < filtered.length - 1
                                          ? colors.secondaryTextAlt
                                          : colors.tertiaryText.withValues(alpha: 0.35),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => Center(
                      child: Text(
                        l10n.isTurkish ? 'Yüklenemedi' : 'Failed to load',
                        style: TextStyle(color: colors.secondaryTextAlt),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final AppThemeColors colors;
  final bool isPrimary;
  final VoidCallback onTap;

  const _SheetActionButton({
    required this.icon,
    required this.label,
    required this.colors,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isPrimary
        ? colors.accent.withValues(alpha: 0.13)
        : colors.cardBackground;
    final fgColor = isPrimary ? colors.accent : colors.primaryText;
    final borderColor = isPrimary
        ? colors.accent.withValues(alpha: 0.35)
        : colors.borderStroke;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: colors.accent),
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: fgColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
