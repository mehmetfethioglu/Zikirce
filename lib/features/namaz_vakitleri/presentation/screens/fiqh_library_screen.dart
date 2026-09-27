import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../data/farz_32_data.dart';
import '../../domain/models/farz_knowledge_item.dart';

const Color _emeraldColor = Color(0xFF10B981);

class FiqhLibraryScreen extends StatelessWidget {
  final int? initialFarzId;

  const FiqhLibraryScreen({
    super.key,
    this.initialFarzId,
  });

  @override
  Widget build(BuildContext context) {
    return FiqhLibraryView(
      isEmbedded: false,
      initialFarzId: initialFarzId,
    );
  }
}

class FiqhLibraryView extends StatefulWidget {
  final bool isEmbedded;
  final int? initialFarzId;

  const FiqhLibraryView({
    super.key,
    this.isEmbedded = false,
    this.initialFarzId,
  });

  @override
  State<FiqhLibraryView> createState() => _FiqhLibraryViewState();
}

class _FiqhLibraryViewState extends State<FiqhLibraryView> {
  String _selectedCategoryName = 'Tümü';
  String _searchQuery = '';
  final Set<int> _readFarzIds = {};
  bool _isLoadingProgress = true;
  final TextEditingController _searchController = TextEditingController();

  static const String _completedFarzPrefKey = 'CompletedFarzIds_v1';

  @override
  void initState() {
    super.initState();
    _loadReadStatus();

    if (widget.initialFarzId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = kFarz32List.cast<FarzKnowledgeItem?>().firstWhere(
              (item) => item?.id == widget.initialFarzId,
              orElse: () => null,
            );
        if (target != null && mounted) {
          _openFarzDetailSheet(target);
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReadStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedList = prefs.getStringList(_completedFarzPrefKey) ?? [];
      final ids = savedList.map(int.tryParse).whereType<int>().toSet();
      if (mounted) {
        setState(() {
          _readFarzIds.clear();
          _readFarzIds.addAll(ids);
          _isLoadingProgress = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingProgress = false);
      }
    }
  }

  Future<void> _toggleReadStatus(int farzId) async {
    HapticService.selectionClick();
    final isAlreadyRead = _readFarzIds.contains(farzId);
    setState(() {
      if (isAlreadyRead) {
        _readFarzIds.remove(farzId);
      } else {
        _readFarzIds.add(farzId);
      }
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _completedFarzPrefKey,
        _readFarzIds.map((id) => id.toString()).toList(),
      );
    } catch (_) {}
  }

  List<FarzKnowledgeItem> get _filteredList {
    return kFarz32List.where((item) {
      final matchesCategory = _selectedCategoryName == 'Tümü' ||
          item.category.shortName == _selectedCategoryName ||
          item.category.displayName == _selectedCategoryName;

      final query = _searchQuery.toLowerCase();
      final matchesSearch = query.isEmpty ||
          item.title.toLowerCase().contains(query) ||
          item.term.toLowerCase().contains(query) ||
          item.notificationSummary.toLowerCase().contains(query) ||
          item.fullContent.toLowerCase().contains(query);

      return matchesCategory && matchesSearch;
    }).toList();
  }

  void _openFarzDetailSheet(FarzKnowledgeItem item) {
    HapticService.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FarzDetailModalSheet(
        item: item,
        isRead: _readFarzIds.contains(item.id),
        onToggleRead: () => _toggleReadStatus(item.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final items = _filteredList;
    final completedCount = _readFarzIds.length;
    final totalCount = kFarz32List.length;
    final progressRatio = totalCount > 0 ? (completedCount / totalCount) : 0.0;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.isEmbedded) ...[
          Text(
            '32 Farz İlmihal Rehberi',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colors.primaryText,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 12),
        ],
        // 1. Progress Banner
        _buildProgressBanner(colors, completedCount, totalCount, progressRatio),
        const SizedBox(height: 14),

        // 2. Search Bar
        _buildSearchBar(colors),
        const SizedBox(height: 12),

        // 3. Category Filter Chips
        _buildCategoryFilters(colors),
        const SizedBox(height: 16),

        // 4. Farz Cards List
        if (items.isEmpty)
          _buildEmptyState(colors)
        else
          ...items.map((item) => _buildFarzCard(colors, item)),
      ],
    );

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        backgroundColor: colors.headerBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: colors.primaryText, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '32 Farz İlmihal Rehberi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.primaryText,
              ),
            ),
            Text(
              'Diyanet İşleri Başkanlığı İlmihali Kaynaklı',
              style: TextStyle(
                fontSize: 11,
                color: colors.secondaryTextAlt,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          content,
        ],
      ),
    );
  }

  Widget _buildProgressBanner(
    AppThemeColors colors,
    int completed,
    int total,
    double ratio,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.borderStroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
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
                  color: colors.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.auto_stories_rounded,
                    color: colors.accent, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '32 Farz Tamamlama Durumu',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colors.primaryText,
                      ),
                    ),
                    Text(
                      '$completed / $total farz okundu (${(ratio * 100).toInt()}%)',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.secondaryTextAlt,
                      ),
                    ),
                  ],
                ),
              ),
              if (completed == total && total > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _emeraldColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '🏆 Tamamlandı',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _emeraldColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _isLoadingProgress ? 0 : ratio,
              minHeight: 8,
              backgroundColor: colors.borderStroke.withValues(alpha: 0.4),
              valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(AppThemeColors colors) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderStroke),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val.trim()),
        style: TextStyle(fontSize: 14, color: colors.primaryText),
        decoration: InputDecoration(
          hintText: 'Farz, şart veya fıkhi konu ara...',
          hintStyle: TextStyle(
            fontSize: 13,
            color: colors.secondaryTextAlt.withValues(alpha: 0.6),
          ),
          prefixIcon: Icon(Icons.search_rounded,
              color: colors.secondaryTextAlt, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded,
                      color: colors.secondaryTextAlt, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildCategoryFilters(AppThemeColors colors) {
    final categories = [
      'Tümü',
      'İman',
      'İslam',
      'Abdest',
      'Gusül',
      'Teyemmüm',
      'Namaz Şartları',
      'Namaz Rükünleri',
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final cat = categories[idx];
          final isSelected = _selectedCategoryName == cat;

          return InkWell(
            onTap: () {
              HapticService.selectionClick();
              setState(() => _selectedCategoryName = cat);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? colors.accent : colors.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? colors.accent : colors.borderStroke,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                cat,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : colors.primaryText,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFarzCard(AppThemeColors colors, FarzKnowledgeItem item) {
    final isRead = _readFarzIds.contains(item.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isRead
              ? colors.accent.withValues(alpha: 0.3)
              : colors.borderStroke,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _openFarzDetailSheet(item),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Tag & Read Status
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'FARZ #${item.id} • ${item.category.shortName.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: colors.accent,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      isRead
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: isRead
                          ? _emeraldColor
                          : colors.secondaryTextAlt.withValues(alpha: 0.4),
                      size: 22,
                    ),
                    onPressed: () => _toggleReadStatus(item.id),
                    tooltip: isRead ? 'Okundu' : 'Okundu olarak işaretle',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Title & Arabic Term
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colors.primaryText,
                      ),
                    ),
                  ),
                  if (item.term.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        item.term,
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                          color: colors.secondaryTextAlt,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),

              // Concise Notification Summary
              Text(
                item.notificationSummary,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: colors.secondaryTextAlt,
                ),
              ),
              const SizedBox(height: 10),

              // Footer: Citation and "Detayı Oku" action
              Row(
                children: [
                  Icon(Icons.menu_book_rounded,
                      size: 13, color: colors.secondaryTextAlt.withValues(alpha: 0.8)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.sourceCitation,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.secondaryTextAlt.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  Text(
                    'İlmihali Oku →',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: colors.accent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppThemeColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.search_off_rounded,
                size: 48,
                color: colors.secondaryTextAlt.withValues(alpha: 0.5)),
            const SizedBox(height: 8),
            Text(
              'Aramanıza uygun farz veya konu bulunamadı.',
              style: TextStyle(color: colors.secondaryTextAlt, fontSize: 13.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rich reading view modal bottom sheet for 32 Farz articles
class _FarzDetailModalSheet extends StatefulWidget {
  final FarzKnowledgeItem item;
  final bool isRead;
  final VoidCallback onToggleRead;

  const _FarzDetailModalSheet({
    required this.item,
    required this.isRead,
    required this.onToggleRead,
  });

  @override
  State<_FarzDetailModalSheet> createState() => _FarzDetailModalSheetState();
}

class _FarzDetailModalSheetState extends State<_FarzDetailModalSheet> {
  late bool _currentRead;

  @override
  void initState() {
    super.initState();
    _currentRead = widget.isRead;
  }

  void _copyToClipboard(BuildContext context) {
    final text = '32 Farz - Farz #${widget.item.id}: ${widget.item.title}\n\n'
        '${widget.item.notificationSummary}\n\n'
        '${widget.item.fullContent}\n\n'
        'Kaynak: ${widget.item.sourceCitation}';

    Clipboard.setData(ClipboardData(text: text));
    HapticService.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Farz bilgisi panoya kopyalandı 📋'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final item = widget.item;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.cardBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag Indicator Handle
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4.5,
                decoration: BoxDecoration(
                  color: colors.secondaryTextAlt.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              // Modal Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'FARZ #${item.id} • ${item.category.displayName}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colors.accent,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.share_outlined,
                          color: colors.primaryText, size: 20),
                      onPressed: () => _copyToClipboard(context),
                      tooltip: 'Metni Kopyala / Paylaş',
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: colors.primaryText, size: 22),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Scrollable Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    // Main Title
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: colors.primaryText,
                      ),
                    ),
                    if (item.term.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.term,
                        style: TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: colors.accent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),

                    // Notification summary highlight quote box
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: colors.accent.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.notifications_active_outlined,
                              color: colors.accent, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ezan Bildirimi Özeti',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: colors.accent,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.notificationSummary,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: colors.primaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Key Points if present
                    if (item.keyPoints.isNotEmpty) ...[
                      Text(
                        'Öne Çıkan Esaslar',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...item.keyPoints.map(
                        (point) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: colors.accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  point,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: colors.primaryText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Full Ilmihal Content
                    Text(
                      'Diyanet İlmihali Açıklaması',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.fullContent,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        letterSpacing: 0.2,
                        color: colors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Citation Footnote
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.pageBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.borderStroke),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.verified_outlined,
                              color: colors.accent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Kaynak: ${item.sourceCitation}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: colors.secondaryTextAlt,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Action Bar: Toggle Read Button
              SafeArea(
                top: false,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() => _currentRead = !_currentRead);
                            widget.onToggleRead();
                          },
                          icon: Icon(
                            _currentRead
                                ? Icons.check_circle_rounded
                                : Icons.check_circle_outline_rounded,
                            color: _currentRead ? _emeraldColor : colors.accent,
                            size: 18,
                          ),
                          label: Text(
                            _currentRead
                                ? 'Okundu Olarak Kaydedildi'
                                : 'Okundu Olarak İşaretle',
                            style: TextStyle(
                              color:
                                  _currentRead ? _emeraldColor : colors.accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(
                              color: _currentRead
                                  ? _emeraldColor
                                  : colors.accent,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
