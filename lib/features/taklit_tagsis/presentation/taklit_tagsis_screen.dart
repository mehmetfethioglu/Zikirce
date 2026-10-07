import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/taklit_tagsis_service.dart';
import 'widgets/taklit_tagsis_detail_sheet.dart';

class TaklitTagsisScreen extends StatefulWidget {
  const TaklitTagsisScreen({super.key});

  @override
  State<TaklitTagsisScreen> createState() => _TaklitTagsisScreenState();
}

class _TaklitTagsisScreenState extends State<TaklitTagsisScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<TaklitTagsisBrandGroup> _brandGroups = [];
  List<TaklitTagsisBrandGroup> _filteredGroups = [];
  int _totalRawRecords = 0;
  DateTime? _lastSyncDate;
  bool _isLoading = true;
  bool _isSyncing = false;

  String _selectedCategory = 'Tümü';
  String _selectedRiskFilter = 'ALL'; // 'ALL', 'HAZARD', 'FRAUD'

  final List<String> _categories = [
    'Tümü',
    'Süt ve Süt Ürünleri',
    'Et ve Et Ürünleri',
    'Bitkisel Yağlar',
    'Baharatlar',
    'Alkolsüz İçecekler',
    'Bal ve Arı Ürünleri',
    'Çikolata ve Şekerleme',
    'Bitki, Çay ve Kahve',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final rawItems = await TaklitTagsisService.getAllItems();
    final groups = TaklitTagsisService.groupItemsByBrand(rawItems);
    final lastSync = await TaklitTagsisService.getLastSyncDate();

    if (!mounted) return;
    setState(() {
      _totalRawRecords = rawItems.length;
      _brandGroups = groups;
      _lastSyncDate = lastSync;
      _applyFilter();
      _isLoading = false;
    });
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();

    setState(() {
      _filteredGroups = _brandGroups.where((group) {
        // 1. Risk Level Filter
        if (_selectedRiskFilter == 'HAZARD' && !group.hasHealthHazard) {
          return false;
        }
        if (_selectedRiskFilter == 'FRAUD' && group.hasHealthHazard) {
          return false;
        }

        // 2. Category Filter
        if (_selectedCategory != 'Tümü') {
          final catQuery = _selectedCategory.toLowerCase();
          final matchesGroupCat = group.primaryCategory.toLowerCase().contains(catQuery);
          final matchesProductCat = group.products.any((p) => p.category.toLowerCase().contains(catQuery));
          if (!matchesGroupCat && !matchesProductCat) {
            return false;
          }
        }

        // 3. Multi-field Query Search
        if (query.isNotEmpty) {
          final matchesBrand = group.brandName.toLowerCase().contains(query);
          final matchesCompany = group.companyName.toLowerCase().contains(query);
          final matchesReasons = group.uniqueReasons.any((r) => r.toLowerCase().contains(query));
          final matchesProduct = group.products.any((p) =>
              p.productName.toLowerCase().contains(query) ||
              p.reason.toLowerCase().contains(query));

          if (!matchesBrand && !matchesCompany && !matchesReasons && !matchesProduct) {
            return false;
          }
        }

        return true;
      }).toList();
    });
  }

  Future<void> _syncLatest() async {
    setState(() => _isSyncing = true);
    final addedCount = await TaklitTagsisService.syncLatestList();
    await _loadData();
    setState(() => _isSyncing = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            addedCount > 0
                ? 'Buluttan $addedCount yeni bakanlık kaydı eklendi.'
                : 'Bakanlık taklit/tağşiş veritabanı en güncel durumda.',
          ),
          backgroundColor: AppColors.primaryEmerald,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
      'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final surfaceColor = context.surfaceColor;
    final borderColor = context.cardBorderColor;
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;

    final int hazardCount = _brandGroups.where((g) => g.hasHealthHazard).length;
    final int fraudCount = _brandGroups.length - hazardCount;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bakanlık Kara Listesi',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (!_isLoading)
              Text(
                '${_filteredGroups.length} Marka / Firma Listeleniyor',
                style: TextStyle(color: textSecondary, fontSize: 11.5, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryMint),
                  )
                : const Icon(Icons.sync_rounded, color: AppColors.primaryMint),
            tooltip: 'Bakanlıktan Güncelle',
            onPressed: _isSyncing ? null : _syncLatest,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _syncLatest,
        color: AppColors.dangerRed,
        child: Column(
          children: [
            // 1. Sleek, Compact Ministry Trust Strip (Single Line, Clean)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                border: Border(bottom: BorderSide(color: borderColor, width: 0.8)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.verified_user_rounded,
                    size: 15,
                    color: AppColors.primaryEmerald.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'T.C. Tarım ve Orman Bakanlığı Resmi Duyuruları ($_totalRawRecords Hileli Ürün İlanı)',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_lastSyncDate != null)
                    Text(
                      _formatDate(_lastSyncDate!),
                      style: TextStyle(color: textSecondary.withValues(alpha: 0.8), fontSize: 11),
                    ),
                ],
              ),
            ),

            // 2. Modern Minimalist Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => _applyFilter(),
                style: TextStyle(color: textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Marka, firma veya hile ara (örn: at eti, nişasta)...',
                  hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6), fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryMint, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _applyFilter();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: surfaceColor,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primaryEmerald, width: 1.5),
                  ),
                ),
              ),
            ),

            // 3. Segmented Filter Switcher (Tümü, Sağlık Tehlikesi, Tağşiş)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _buildSegmentButton(
                      title: 'Tümü (${_brandGroups.length})',
                      value: 'ALL',
                      color: AppColors.primaryEmerald,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      isDark: isDark,
                    ),
                    _buildSegmentButton(
                      title: '🚨 Sağlık ($hazardCount)',
                      value: 'HAZARD',
                      color: AppColors.dangerRed,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      isDark: isDark,
                    ),
                    _buildSegmentButton(
                      title: '⚠️ Tağşiş ($fraudCount)',
                      value: 'FRAUD',
                      color: AppColors.cautionGold,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),

            // 4. Horizontal Minimal Category Scroll
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 4),
              child: SizedBox(
                height: 32,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedCategory = cat;
                            _applyFilter();
                          });
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark ? AppColors.primaryEmerald.withValues(alpha: 0.25) : AppColors.primaryEmerald)
                                : surfaceColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryEmerald
                                  : borderColor.withValues(alpha: 0.8),
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            cat,
                            style: TextStyle(
                              color: isSelected
                                  ? (isDark ? AppColors.primaryMint : Colors.white)
                                  : textSecondary,
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 6),

            // 5. Clean, Minimalist Brand List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primaryEmerald))
                  : _filteredGroups.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 48,
                                  color: AppColors.primaryEmerald.withValues(alpha: 0.8),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Aramanızla eşleşen kara liste kaydı bulunamadı.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Filtreleri sıfırlayarak tüm listeyi görüntüleyebilirsiniz.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: textSecondary, fontSize: 12),
                                ),
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _selectedCategory = 'Tümü';
                                      _selectedRiskFilter = 'ALL';
                                      _applyFilter();
                                    });
                                  },
                                  icon: const Icon(Icons.refresh_rounded, size: 16),
                                  label: const Text('Filtreleri Temizle'),
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                          itemCount: _filteredGroups.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final group = _filteredGroups[index];
                            return _TaklitTagsisBrandCard(
                              group: group,
                              formatDate: _formatDate,
                              onTap: () => TaklitTagsisDetailSheet.show(context, group),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentButton({
    required String title,
    required String value,
    required Color color,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
  }) {
    final isSelected = _selectedRiskFilter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedRiskFilter = value;
            _applyFilter();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? (isDark ? Colors.white : color) : textSecondary,
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

/// Standalone, high-legibility minimalist Brand Card
class _TaklitTagsisBrandCard extends StatelessWidget {
  final TaklitTagsisBrandGroup group;
  final String Function(DateTime) formatDate;
  final VoidCallback onTap;

  const _TaklitTagsisBrandCard({
    required this.group,
    required this.formatDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final surfaceColor = context.surfaceColor;
    final borderColor = context.cardBorderColor;
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;

    final Color accentColor = group.hasHealthHazard ? AppColors.dangerRed : AppColors.cautionGold;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Sleek 4px Color Indicator Bar on the Left
                  Container(
                    width: 4.5,
                    color: accentColor,
                  ),

                  // 2. Card Content Body
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Line: Brand Name + Risk Pill
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  group.brandName,
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: isDark ? 0.2 : 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  group.hasHealthHazard ? '🚨 Sağlık Riski' : '⚠️ Tağşiş',
                                  style: TextStyle(
                                    color: accentColor,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),

                          // Second Line: Category & Company
                          Text(
                            '${group.primaryCategory} • ${group.companyName}',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),

                          // Third Line: High-Legibility Violation Summary Strip
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: isDark ? 0.12 : 0.06),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.search_rounded,
                                  size: 13,
                                  color: accentColor,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    group.primaryReasonSummary,
                                    style: TextStyle(
                                      color: isDark ? textPrimary : (group.hasHealthHazard ? const Color(0xFFB91C1C) : const Color(0xFFB45309)),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Footer Line: Product Count, Date, and Sleek Chevron
                          Row(
                            children: [
                              Text(
                                '${group.productCount} Uygunsuz Ürün İlanı',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '•',
                                style: TextStyle(color: textSecondary.withValues(alpha: 0.5), fontSize: 10),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Duyuru: ${formatDate(group.latestAnnouncedAt)}',
                                style: TextStyle(
                                  color: textSecondary.withValues(alpha: 0.8),
                                  fontSize: 11,
                                ),
                              ),
                              const Spacer(),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'İncele',
                                    style: TextStyle(
                                      color: AppColors.primaryMint,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 16,
                                    color: AppColors.primaryMint,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
