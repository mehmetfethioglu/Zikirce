import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/services/widget_sync_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../gamification/providers/gamification_providers.dart';
import '../../../gamification/services/daily_streak_service.dart';
import '../../../kuran/providers/kuran_providers.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../providers/zikir_providers.dart';

class AddEditZikirSheet extends ConsumerStatefulWidget {
  final Zikir? zikir;
  final int initialTabIndex;
  final Function(drift.Insertable<Zikir>)? onSave;
  final Function(Zikir targetZikir, int amount)? onTransfer;

  const AddEditZikirSheet({
    super.key,
    this.zikir,
    this.initialTabIndex = 0,
    this.onSave,
    this.onTransfer,
  });

  static Future<void> show(
    BuildContext context, {
    Zikir? zikir,
    int initialTabIndex = 0,
    Function(drift.Insertable<Zikir>)? onSave,
    Function(Zikir targetZikir, int amount)? onTransfer,
  }) {
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEditZikirSheet(
        zikir: zikir,
        initialTabIndex: initialTabIndex,
        onSave: onSave,
        onTransfer: onTransfer,
      ),
    );
  }

  @override
  ConsumerState<AddEditZikirSheet> createState() => _AddEditZikirSheetState();
}

class _AddEditZikirSheetState extends ConsumerState<AddEditZikirSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late int _activeTabIndex;

  // --- TAB 1 (Yeni / Düzenle) Controllers ---
  late TextEditingController _nameController;
  late TextEditingController _arabicController;
  late TextEditingController _targetController;
  String _selectedCategory = 'Hadislerden Zikirler';
  bool _isFavorite = false;

  // --- TAB 2 (Zikirmatikten Aktar) Controllers ---
  late TextEditingController _transferAmountController;
  Zikir? _selectedTransferZikir;

  final List<String> _categories = [
    'Hadislerden Zikirler',
    'Esmaül-Hüsna',
    'Dualar',
    'Tesbihat',
    'Tevhid',
    'Salavat',
    'İstiğfar',
    'Hazine',
    'Özel',
  ];

  final List<int> _quickTargets = [33, 99, 100, 500, 1000];
  final List<int> _quickTransferAmounts = [33, 99, 100, 500, 1000];

  @override
  void initState() {
    super.initState();
    _activeTabIndex = widget.zikir != null ? 0 : widget.initialTabIndex;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: _activeTabIndex.clamp(0, 1),
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _activeTabIndex = _tabController.index;
        });
      }
    });

    _nameController = TextEditingController(text: widget.zikir?.name ?? '');
    _arabicController = TextEditingController(text: widget.zikir?.arabic ?? '');
    _targetController = TextEditingController(
      text: (widget.zikir?.target ?? 33).toString(),
    );
    _selectedCategory = widget.zikir?.category ?? 'Hadislerden Zikirler';
    if (!_categories.contains(_selectedCategory)) {
      _categories.insert(0, _selectedCategory);
    }
    _isFavorite = widget.zikir?.isFavorite ?? false;

    _transferAmountController = TextEditingController();
    _selectedTransferZikir = widget.zikir;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _arabicController.dispose();
    _targetController.dispose();
    _transferAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final zikirsAsync = ref.watch(zikirListStreamProvider);

    final isEditMode = widget.zikir != null && widget.initialTabIndex == 0;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: colors.borderStroke, width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: 8 + bottomInset,
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Drag Handle
          Center(
            child: Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: colors.borderStroke,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),

          // 2. Header (Title, Subtitle, Close Button)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  _activeTabIndex == 0 ? '📿' : '📥',
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEditMode
                          ? (l10n.isTurkish ? 'Zikri Düzenle' : 'Edit Dhikr')
                          : (_activeTabIndex == 0
                              ? l10n.addZikirNewTitle
                              : l10n.addZikirImportTitle),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEditMode
                          ? (l10n.isTurkish ? 'Zikir bilgilerini güncelleyin' : 'Update dhikr details')
                          : (_activeTabIndex == 0
                              ? (l10n.isTurkish ? 'Kendi zikirlerinizi oluşturun' : 'Create your custom dhikrs')
                              : (l10n.isTurkish ? 'Çekilmiş zikirlerinizi sisteme dahil edin' : 'Add recited counts to your total')),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: colors.secondaryTextAlt,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colors.pageBackground,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.borderStroke),
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: colors.secondaryText,
                  ),
                ),
              ),
            ],
          ),

          // 3. Tab Bar Selector (Only when NOT editing existing zikir)
          if (!isEditMode) ...[
            const SizedBox(height: 14),
            Container(
              height: 42,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: colors.pageBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.borderStroke),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticService.selectionClick();
                        _tabController.animateTo(0);
                        setState(() => _activeTabIndex = 0);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: _activeTabIndex == 0
                              ? colors.accent
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(11),
                          boxShadow: _activeTabIndex == 0
                              ? [
                                  BoxShadow(
                                    color: colors.accent.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          l10n.addZikirNewTitle,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _activeTabIndex == 0
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: _activeTabIndex == 0
                                ? Colors.white
                                : colors.secondaryTextAlt,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticService.selectionClick();
                        _tabController.animateTo(1);
                        setState(() => _activeTabIndex = 1);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: _activeTabIndex == 1
                              ? colors.accent
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(11),
                          boxShadow: _activeTabIndex == 1
                              ? [
                                  BoxShadow(
                                    color: colors.accent.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          l10n.addZikirImportTitle,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _activeTabIndex == 1
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: _activeTabIndex == 1
                                ? Colors.white
                                : colors.secondaryTextAlt,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // 4. Tab Contents (Scrollable)
          Flexible(
            child: SingleChildScrollView(
              child: isEditMode || _activeTabIndex == 0
                  ? _buildAddEditForm(context, colors, l10n, isEditMode)
                  : _buildTransferForm(context, colors, l10n, zikirsAsync),
            ),
          ),

          const SizedBox(height: 12),

          // 5. Action Buttons (Cancel / Save / Transfer)
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colors.borderStroke),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      foregroundColor: colors.primaryText,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      l10n.commonCancel,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      if (isEditMode || _activeTabIndex == 0) {
                        _handleSaveDhikr(context, colors, l10n, isEditMode);
                      } else {
                        _handleTransferDhikr(context, colors, l10n);
                      }
                    },
                    child: Text(
                      isEditMode
                          ? l10n.commonSave
                          : (_activeTabIndex == 0
                              ? l10n.commonAdd
                              : l10n.commonImport),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

  // =========================================================================
  // TAB 1: YENİ ZİKİR EKLE / DÜZENLEME FORMU
  // =========================================================================
  Widget _buildAddEditForm(
    BuildContext context,
    AppThemeColors colors,
    AppLocalizations l10n,
    bool isEditMode,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Zikir Adı
        Text(
          l10n.isTurkish ? 'Zikir Adı *' : 'Dhikr Name *',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: colors.primaryText,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _nameController,
          style: TextStyle(color: colors.primaryText, fontSize: 14.5),
          decoration: InputDecoration(
            hintText: l10n.addZikirNamePlaceholder,
            hintStyle: TextStyle(color: colors.secondaryTextAlt, fontSize: 13),
            filled: true,
            fillColor: colors.pageBackground,
            prefixIcon: Icon(Icons.bookmark_border_rounded, size: 20, color: colors.accent),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.borderStroke),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.borderStroke),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.accent, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 12),

        // Hedef Sayı
        Text(
          l10n.zikirPageTarget,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: colors.primaryText,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _targetController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(color: colors.primaryText, fontSize: 14.5),
          decoration: InputDecoration(
            hintText: l10n.addZikirTargetPlaceholder,
            hintStyle: TextStyle(color: colors.secondaryTextAlt, fontSize: 13),
            filled: true,
            fillColor: colors.pageBackground,
            prefixIcon: Icon(Icons.adjust_rounded, size: 20, color: colors.accent),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.borderStroke),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.borderStroke),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.accent, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 6),

        // Quick Target Chips
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _quickTargets.map((q) {
            final isCurrent = _targetController.text == q.toString();
            return ActionChip(
              label: Text(
                '$q',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                  color: isCurrent ? Colors.white : colors.primaryText,
                ),
              ),
              backgroundColor: isCurrent ? colors.accent : colors.pageBackground,
              side: BorderSide(color: isCurrent ? colors.accent : colors.borderStroke),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onPressed: () {
                HapticService.selectionClick();
                setState(() => _targetController.text = q.toString());
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),

        // Kategori Seçici
        Text(
          l10n.isTurkish ? 'Kategori' : 'Category',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: colors.primaryText,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _selectedCategory,
          dropdownColor: colors.cardBackground,
          style: TextStyle(color: colors.primaryText, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: colors.pageBackground,
            prefixIcon: Icon(Icons.category_outlined, size: 20, color: colors.accent),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.borderStroke),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.borderStroke),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.accent, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          items: _categories.map((cat) {
            return DropdownMenuItem(
              value: cat,
              child: Text(cat),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedCategory = val);
          },
        ),
        const SizedBox(height: 12),

        // Arapça Metin (İsteğe Bağlı)
        Text(
          l10n.isTurkish ? 'Arapça Metin (İsteğe Bağlı)' : 'Arabic Text (Optional)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: colors.primaryText,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _arabicController,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontFamily: ref.watch(arabicFontFamilyProvider),
            fontSize: 20,
            fontWeight: ref.watch(isBoldArabicProvider) ? FontWeight.bold : FontWeight.normal,
            color: colors.zikirArabicColor,
          ),
          decoration: InputDecoration(
            hintText: l10n.addZikirArabicPlaceholder,
            hintTextDirection: TextDirection.rtl,
            hintStyle: TextStyle(
              fontFamily: ref.watch(arabicFontFamilyProvider),
              color: colors.secondaryTextAlt.withValues(alpha: 0.6),
              fontSize: 18,
            ),
            filled: true,
            fillColor: colors.pageBackground,
            prefixIcon: Icon(Icons.menu_book_rounded, size: 20, color: colors.accent),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.borderStroke),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.borderStroke),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.accent, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
        const SizedBox(height: 12),

        // Favorilere Ekle Switch
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: colors.pageBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.borderStroke),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    _isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                    color: _isFavorite ? const Color(0xFFF59E0B) : colors.secondaryTextAlt,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.isTurkish ? 'Favorilere Ekle' : 'Add to Favorites',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.primaryText,
                    ),
                  ),
                ],
              ),
              Switch.adaptive(
                value: _isFavorite,
                activeTrackColor: colors.accent,
                onChanged: (val) {
                  HapticService.selectionClick();
                  setState(() => _isFavorite = val);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Bilgilendirme Notu
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colors.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('💡', style: TextStyle(fontSize: 14, color: colors.accent)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.addZikirFilterTip,
                  style: TextStyle(fontSize: 11, color: colors.secondaryTextAlt),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 2: ZİKİRMATİKTEN AKTAR FORMU
  // =========================================================================
  Widget _buildTransferForm(
    BuildContext context,
    AppThemeColors colors,
    AppLocalizations l10n,
    AsyncValue<List<Zikir>> zikirsAsync,
  ) {
    return zikirsAsync.when(
      data: (zikirList) {
        if (zikirList.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                l10n.isTurkish ? 'Kayıtlı zikir bulunamadı.' : 'No saved dhikrs found.',
                style: TextStyle(color: colors.secondaryTextAlt),
              ),
            ),
          );
        }

        // Default to first dhikr if none selected
        _selectedTransferZikir ??= zikirList.first;

        // Ensure selected zikir exists in the current list
        final currentSelection = zikirList.firstWhere(
          (z) => z.id == _selectedTransferZikir?.id,
          orElse: () => zikirList.first,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Zikir Seçimi
            Text(
              l10n.addZikirSelectDhikr,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: colors.primaryText,
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              initialValue: currentSelection.id,
              dropdownColor: colors.cardBackground,
              isExpanded: true,
              style: TextStyle(color: colors.primaryText, fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: colors.pageBackground,
                prefixIcon: Icon(Icons.touch_app_rounded, size: 20, color: colors.accent),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colors.borderStroke),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colors.borderStroke),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colors.accent, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              items: zikirList.map((z) {
                return DropdownMenuItem<int>(
                  value: z.id,
                  child: Text(
                    '${z.name} (${z.category})',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (id) {
                if (id != null) {
                  final found = zikirList.firstWhere((element) => element.id == id);
                  setState(() => _selectedTransferZikir = found);
                }
              },
            ),
            const SizedBox(height: 10),

            // 2. Seçili Zikir Önizleme Kartı
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.accent.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colors.accent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '📿',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentSelection.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: colors.primaryText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${l10n.zikirPageTotal}: ${currentSelection.totalCount} · ${currentSelection.category}',
                              style: TextStyle(fontSize: 11.5, color: colors.secondaryTextAlt),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (currentSelection.arabic != null && currentSelection.arabic!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: colors.pageBackground.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.centerRight,
                      child: Text(
                        currentSelection.arabic!,
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontFamily: ref.watch(arabicFontFamilyProvider),
                          fontSize: 15,
                          fontWeight: ref.watch(isBoldArabicProvider) ? FontWeight.bold : FontWeight.normal,
                          color: colors.zikirArabicColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 3. Aktarılacak Miktar
            Text(
              l10n.addZikirRecitedAmount,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: colors.primaryText,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _transferAmountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(
                color: colors.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: l10n.addZikirAmountPlaceholder,
                hintStyle: TextStyle(
                  color: colors.secondaryTextAlt,
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
                filled: true,
                fillColor: colors.pageBackground,
                prefixIcon: Icon(Icons.add_chart_rounded, size: 20, color: colors.accent),
                suffixIcon: _transferAmountController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, size: 18, color: colors.secondaryTextAlt),
                        onPressed: () => setState(() => _transferAmountController.clear()),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colors.borderStroke),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colors.borderStroke),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colors.accent, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),

            // 4. Quick Increment Chips (+33, +99, +100, +500, +1000)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _quickTransferAmounts.map((amt) {
                return ActionChip(
                  label: Text(
                    '+$amt',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: colors.accent,
                    ),
                  ),
                  backgroundColor: colors.accent.withValues(alpha: 0.10),
                  side: BorderSide(color: colors.accent.withValues(alpha: 0.25)),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onPressed: () {
                    HapticService.selectionClick();
                    final current = int.tryParse(_transferAmountController.text.trim()) ?? 0;
                    final next = current + amt;
                    setState(() => _transferAmountController.text = next.toString());
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // 5. Bilgi Kutucuğu
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.pageBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.borderStroke),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Text('💡', style: TextStyle(fontSize: 14)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.addZikirImportTip,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: colors.secondaryTextAlt,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: Padding(
        padding: EdgeInsets.all(24.0),
        child: CircularProgressIndicator(),
      )),
      error: (err, _) => Text('Hata: $err', style: TextStyle(color: colors.secondaryTextAlt)),
    );
  }

  // =========================================================================
  // ACTIONS / HANDLERS
  // =========================================================================

  void _handleSaveDhikr(
    BuildContext context,
    AppThemeColors colors,
    AppLocalizations l10n,
    bool isEditMode,
  ) {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.isTurkish ? 'Lütfen zikir adını girin.' : 'Please enter dhikr name.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    final target = int.tryParse(_targetController.text.trim()) ?? 33;
    final arabic = _arabicController.text.trim();

    final comp = ZikirsCompanion(
      name: drift.Value(name),
      arabic: arabic.isNotEmpty ? drift.Value(arabic) : const drift.Value.absent(),
      target: drift.Value(target),
      category: drift.Value(_selectedCategory),
      isFavorite: drift.Value(_isFavorite),
    );

    if (widget.onSave != null) {
      widget.onSave!(comp);
    }

    HapticService.selectionClick();
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isEditMode
                    ? (l10n.isTurkish ? "'$name' güncellendi!" : "'$name' updated!")
                    : (l10n.isTurkish ? "'$name' zikri eklendi!" : "'$name' dhikr added!"),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: colors.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _handleTransferDhikr(
    BuildContext context,
    AppThemeColors colors,
    AppLocalizations l10n,
  ) async {
    final target = _selectedTransferZikir;
    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.isTurkish ? 'Lütfen listeden bir zikir seçin.' : 'Please select a dhikr.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    final amountText = _transferAmountController.text.trim();
    final amount = int.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.isTurkish ? 'Lütfen geçerli bir çekilen zikir miktarı girin.' : 'Please enter a valid recited amount.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    final db = ref.read(databaseProvider);

    // 1. Update target zikir total count & lastPracticed in DB
    final newTotal = target.totalCount + amount;
    await (db.update(db.zikirs)..where((t) => t.id.equals(target.id))).write(
      ZikirsCompanion(
        totalCount: drift.Value(newTotal),
        lastPracticed: drift.Value(DateTime.now()),
      ),
    );

    // 2. Insert into ZikirLogs for Bismillah Dashboard / Heatmap / Streak / Stats
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    await db.into(db.zikirLogs).insert(
      ZikirLogsCompanion.insert(
        zikirId: target.id,
        count: amount,
        dateStr: dateStr,
      ),
    );

    // Update SharedPreferences total and daily zikir counts
    final prefs = await SharedPreferences.getInstance();
    final allZikirs = await db.select(db.zikirs).get();
    final zikirsSum = allZikirs.fold<int>(0, (sum, z) => sum + z.totalCount);
    final curTotalZikir = prefs.getInt('TotalZikir') ?? 0;
    await prefs.setInt('TotalZikir', max(curTotalZikir, zikirsSum));
    final curTodayCount = prefs.getInt('TodayZikirCount') ?? 0;
    await prefs.setInt('TodayZikirCount', curTodayCount + amount);

    // Update daily streak
    await DailyStreakService.recordDailyActivity(db);

    // 3. Sync widgets & badges
    WidgetSyncService.syncAll(db);
    ref.read(badgeRefreshTriggerProvider.notifier).state++;

    // 4. Callback if provided
    if (widget.onTransfer != null) {
      widget.onTransfer!(target, amount);
    }

    // 5. Haptic feedback & Toast / SnackBar
    HapticService.targetReached();

    if (context.mounted) {
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.isTurkish
                      ? "'${target.name}' için $amount zikir aktarıldı!"
                      : "$amount dhikr imported for '${target.name}'!",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: colors.accent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
