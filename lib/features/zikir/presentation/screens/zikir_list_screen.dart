import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../kuran/providers/kuran_providers.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../providers/zikir_providers.dart';
import '../widgets/add_edit_zikir_sheet.dart';

class ZikirListScreen extends ConsumerStatefulWidget {
  const ZikirListScreen({super.key});

  @override
  ConsumerState<ZikirListScreen> createState() => _ZikirListScreenState();
}

class _ZikirListScreenState extends ConsumerState<ZikirListScreen> {
  int _selectedCategoryIndex = 0;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<String> _getCategories(AppLocalizations l10n) => [
    l10n.translate('ZikirList_CatAll'),
    l10n.translate('ZikirList_CatFavorites'),
    l10n.translate('ZikirList_CatHadith'),
    l10n.translate('ZikirList_CatEsma'),
    l10n.translate('ZikirList_CatDuas'),
    l10n.translate('ZikirList_CatCustom'),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    final pageBg = colors.pageBackground;
    final cardBg = colors.cardBackground;
    final primaryTextColor = colors.primaryText;
    final secondaryTextColor = colors.secondaryTextAlt;
    final accentColor = colors.accent;
    final borderStroke = colors.borderStroke;

    final categories = _getCategories(l10n);
    final zikirsAsync = ref.watch(zikirListStreamProvider);
    final db = ref.watch(databaseProvider);

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
          // Zikirmatikten Aktar Hızlı Butonu
          IconButton(
            icon: Icon(Icons.archive_outlined, color: accentColor, size: 24),
            tooltip: l10n.addZikirImportTitle,
            onPressed: () {
              HapticService.selectionClick();
              AddEditZikirSheet.show(
                context,
                initialTabIndex: 1,
              );
            },
          ),
          // Yeni Zikir Ekle Butonu
          IconButton(
            icon: Icon(Icons.add_circle_outline_rounded, color: accentColor, size: 26),
            tooltip: l10n.zikirListAddTooltip,
            onPressed: () {
              HapticService.selectionClick();
              AddEditZikirSheet.show(
                context,
                initialTabIndex: 0,
                onSave: (comp) async {
                  await db.into(db.zikirs).insert(comp);
                },
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Search Input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderStroke),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 20, color: accentColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                      style: TextStyle(color: primaryTextColor, fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: l10n.zikirListSearchHint,
                        hintStyle: TextStyle(color: secondaryTextColor, fontSize: 12.5),
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
                        setState(() => _searchQuery = '');
                      },
                      child: Icon(Icons.clear_rounded, size: 16, color: secondaryTextColor),
                    ),
                ],
              ),
            ),
          ),

          // Category Chips
          SizedBox(
            height: 42,
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
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : primaryTextColor,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: accentColor,
                  backgroundColor: cardBg,
                  side: BorderSide(color: isSelected ? accentColor : borderStroke),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  onSelected: (_) {
                    HapticService.selectionClick();
                    setState(() => _selectedCategoryIndex = idx);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 6),

          // Zikir Cards List
          Expanded(
            child: zikirsAsync.when(
              data: (zikirs) {
                final filtered = zikirs.where((z) {
                  final matchesCat = _selectedCategoryIndex == 0 ||
                      (_selectedCategoryIndex == 1 && z.isFavorite) ||
                      (_selectedCategoryIndex == 2 && (z.category.toLowerCase().contains('hadis') || z.category.toLowerCase().contains('hadith'))) ||
                      (_selectedCategoryIndex == 3 && (z.category.toLowerCase().contains('esma') || z.category.toLowerCase().contains('asma'))) ||
                      (_selectedCategoryIndex == 4 && (z.category.toLowerCase().contains('dua') || z.category.toLowerCase().contains('prayer'))) ||
                      (_selectedCategoryIndex == 5 && (z.category.toLowerCase().contains('özel') || z.category.toLowerCase().contains('custom')));
                  final matchesQuery = _searchQuery.isEmpty ||
                      z.name.toLowerCase().contains(_searchQuery) ||
                      (z.arabic != null && z.arabic!.contains(_searchQuery));
                  return matchesCat && matchesQuery;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(l10n.isTurkish ? 'Kayıt bulunamadı' : 'No records found', style: TextStyle(color: secondaryTextColor)),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final zikir = filtered[index];
                    final progress = (zikir.currentCount / (zikir.target > 0 ? zikir.target : 1)).clamp(0.0, 1.0);

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticService.selectionClick();
                          ref.read(selectedZikirIdProvider.notifier).select(zikir.id);
                          context.go('/zikir');
                        },
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: borderStroke),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Badge
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: accentColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: accentColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Name & Target
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          zikir.name,
                                          style: TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.bold,
                                            color: primaryTextColor,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${l10n.zikirPageCounter}: ${zikir.currentCount} / ${zikir.target} · ${l10n.zikirPageTotal}: ${zikir.totalCount}',
                                          style: TextStyle(fontSize: 11, color: secondaryTextColor),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  // Favorite Star Toggle
                                  InkWell(
                                    onTap: () {
                                      HapticService.selectionClick();
                                      (db.update(db.zikirs)..where((t) => t.id.equals(zikir.id)))
                                          .write(ZikirsCompanion(isFavorite: Value(!zikir.isFavorite)));
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: Icon(
                                        zikir.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                                        color: zikir.isFavorite ? const Color(0xFFF59E0B) : Colors.grey,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                  // More Action Menu (Aktar, Düzenle, Sıfırla, Sil)
                                  PopupMenuButton<String>(
                                    icon: Icon(Icons.more_vert_rounded, size: 20, color: colors.secondaryText),
                                    color: cardBg,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      side: BorderSide(color: borderStroke),
                                    ),
                                    onSelected: (action) async {
                                      HapticService.selectionClick();
                                      if (action == 'transfer') {
                                        AddEditZikirSheet.show(
                                          context,
                                          zikir: zikir,
                                          initialTabIndex: 1,
                                        );
                                      } else if (action == 'edit') {
                                        AddEditZikirSheet.show(
                                          context,
                                          zikir: zikir,
                                          initialTabIndex: 0,
                                          onSave: (comp) async {
                                            await (db.update(db.zikirs)..where((t) => t.id.equals(zikir.id))).write(comp);
                                          },
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
                                          await (db.update(db.zikirs)..where((t) => t.id.equals(zikir.id))).write(
                                            const ZikirsCompanion(
                                              currentCount: Value(0),
                                              lap: Value(0),
                                            ),
                                          );
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
                                          await (db.delete(db.zikirs)..where((t) => t.id.equals(zikir.id))).go();
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
                                  ),
                                ],
                              ),
                              // Arabic Text Container (if available)
                              if (zikir.arabic != null && zikir.arabic!.trim().isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: pageBg.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: borderStroke.withValues(alpha: 0.6),
                                      width: 0.8,
                                    ),
                                  ),
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    zikir.arabic!,
                                    textDirection: TextDirection.rtl,
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontFamily: ref.watch(arabicFontFamilyProvider),
                                      fontSize: 16.5,
                                      fontWeight: ref.watch(isBoldArabicProvider)
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      height: 1.55,
                                      color: colors.zikirArabicColor,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              // Progress Bar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 4,
                                  backgroundColor: borderStroke,
                                  valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
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
