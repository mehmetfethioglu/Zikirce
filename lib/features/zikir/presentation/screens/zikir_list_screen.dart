import 'dart:ui';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../kuran/providers/kuran_providers.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../providers/zikir_providers.dart';
import '../widgets/add_edit_zikir_sheet.dart';
import '../widgets/zikir_vakur_card.dart';

class ZikirListScreen extends ConsumerStatefulWidget {
  const ZikirListScreen({super.key});

  @override
  ConsumerState<ZikirListScreen> createState() => _ZikirListScreenState();
}

class _ZikirListScreenState extends ConsumerState<ZikirListScreen> {
  int _selectedCategoryIndex = 0;
  String _searchQuery = '';
  int _currentPage = 0;
  final Set<int> _expandedZikirIds = <int>{};

  final TextEditingController _searchController = TextEditingController();
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.88);
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
        duration: const Duration(milliseconds: 320),
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
    await ref.read(zikirCrudProvider).insertZikir(comp);
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
      debugPrint('Zikir güncelleme hatası: $e');
      if (rethrowOnError) rethrow;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.isTurkish ? 'Güncellenemedi: $e' : 'Update failed: $e'),
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
      debugPrint('Zikir silme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.isTurkish ? 'Silinemedi: $e' : 'Delete failed: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final pageBg = colors.pageBackground;
    final cardBg = colors.cardBackground;
    final primaryTextColor = colors.primaryText;
    final secondaryTextColor = colors.secondaryTextAlt;
    final accentColor = colors.accent;
    final borderStroke = colors.borderStroke;

    final categories = ZikirCardStyleHelper.getCategories(l10n);
    final zikirsAsync = ref.watch(zikirListStreamProvider);
    final arabicFontFamily = ref.watch(arabicFontFamilyProvider.select((v) => v));
    final isBoldArabic = ref.watch(isBoldArabicProvider.select((v) => v));
    final highlightDivine = ref.watch(highlightDivineWordsProvider.select((v) => v));
    final selectedZikirId = ref.watch(selectedZikirIdProvider.select((v) => v));

    final bottomNavClearance = MediaQuery.of(context).padding.bottom + 88.0;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          l10n.zikirListTitle,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: primaryTextColor,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.archive_outlined, color: accentColor, size: 24),
            tooltip: l10n.addZikirImportTitle,
            onPressed: () {
              HapticService.selectionClick();
              AddEditZikirSheet.show(
                context,
                initialTabIndex: 1,
                onSave: _saveNewZikir,
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.add_circle_outline_rounded, color: accentColor, size: 26),
            tooltip: l10n.zikirListAddTooltip,
            onPressed: () {
              HapticService.selectionClick();
              AddEditZikirSheet.show(
                context,
                initialTabIndex: 0,
                onSave: _saveNewZikir,
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: borderStroke.withValues(alpha: 0.7),
                  width: 0.8,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 19, color: secondaryTextColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim().toLowerCase();
                          _resetCarouselToFirstPage();
                        });
                      },
                      style: TextStyle(color: primaryTextColor, fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: l10n.zikirListSearchHint,
                        hintStyle: TextStyle(color: colors.tertiaryText, fontSize: 12.5),
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
                      child: Icon(Icons.clear_rounded, size: 16, color: secondaryTextColor),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final cat = categories[idx];
                final isSelected = _selectedCategoryIndex == idx;
                return ChoiceChip(
                  label: Text(
                    cat,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : secondaryTextColor,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: accentColor,
                  backgroundColor: cardBg,
                  side: BorderSide(
                    color: isSelected ? accentColor : borderStroke.withValues(alpha: 0.6),
                    width: 0.8,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
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
          const SizedBox(height: 4),
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
                      style: TextStyle(color: secondaryTextColor),
                    ),
                  );
                }

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
                              arabicFontSize: ZikirCardStyleHelper.resolveArabicFontSize(
                                zikir.arabic ?? '',
                                isExpanded,
                              ),
                              virtueTitle: ZikirCardStyleHelper.getVirtueSectionTitle(
                                zikir.category,
                                l10n,
                              ),
                              onToggleExpand: () => _toggleExplanation(zikir.id),
                              onToggleFavorite: () {
                                HapticService.selectionClick();
                                _modifyZikir(
                                  zikir.id,
                                  ZikirsCompanion(isFavorite: Value(!zikir.isFavorite)),
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
                              onStartZikir: () {
                                HapticService.selectionClick();
                                ref.read(selectedZikirIdProvider.notifier).select(zikir.id);
                                context.go('/zikir');
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(
                        left: 28,
                        right: 28,
                        top: 2,
                        bottom: bottomNavClearance,
                      ),
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
                                  ? secondaryTextColor
                                  : colors.tertiaryText.withValues(alpha: 0.35),
                            ),
                          ),
                          Text(
                            '${safePage + 1} / ${filtered.length}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                              color: secondaryTextColor,
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
                                  ? secondaryTextColor
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
              error: (err, _) => Center(child: Text('Hata: $err')),
            ),
          ),
        ],
      ),
    );
  }
}
