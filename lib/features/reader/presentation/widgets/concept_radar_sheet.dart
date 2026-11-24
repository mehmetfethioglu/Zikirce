import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../services/offline_ai_service.dart';
import '../providers/reader_provider.dart';

/// Kitap içindeki bir kavramın tüm sayfalardaki geçişlerini, ilk/yoğun geçtiği bölümleri
/// ve aynı bağlamda birlikte geçtiği kavramları (Concordance) listeleyen interaktif alt pencere.
class ConceptRadarSheet extends ConsumerStatefulWidget {
  final String initialConcept;
  final List<String> suggestedConcepts;
  final void Function(int pageNumber) onJumpToPage;

  const ConceptRadarSheet({
    super.key,
    required this.initialConcept,
    required this.suggestedConcepts,
    required this.onJumpToPage,
  });

  static void show(
    BuildContext context, {
    required String initialConcept,
    required List<String> suggestedConcepts,
    required void Function(int pageNumber) onJumpToPage,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => ConceptRadarSheet(
        initialConcept: initialConcept,
        suggestedConcepts: suggestedConcepts,
        onJumpToPage: onJumpToPage,
      ),
    );
  }

  @override
  ConsumerState<ConceptRadarSheet> createState() => _ConceptRadarSheetState();
}

class _ConceptRadarSheetState extends ConsumerState<ConceptRadarSheet> {
  late final TextEditingController _searchController;
  ConceptRadarResult? _result;
  bool _isSearching = true;
  late String _activeConcept;

  @override
  void initState() {
    super.initState();
    _activeConcept = widget.initialConcept.trim().isNotEmpty
        ? widget.initialConcept.trim()
        : (widget.suggestedConcepts.isNotEmpty
            ? widget.suggestedConcepts.first
            : 'İlim');
    _searchController = TextEditingController(text: _activeConcept);
    _runSearch(_activeConcept);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;

    setState(() {
      _activeConcept = clean;
      _isSearching = true;
    });

    final res =
        await ref.read(readerProvider.notifier).buildConceptRadar(clean);
    if (mounted) {
      setState(() {
        _result = res;
        _isSearching = false;
      });
    }
  }

  List<TextSpan> _buildHighlightedSnippetSpans(
    String snippet,
    String stem,
    ThemeData theme,
  ) {
    if (stem.isEmpty) {
      return [TextSpan(text: snippet)];
    }
    final words = snippet.split(' ');
    final spans = <TextSpan>[];
    final lowerStem = stem.toLowerCase();

    for (int i = 0; i < words.length; i++) {
      final w = words[i];
      final cleanW = w
          .replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '')
          .toLowerCase();
      final isHit = cleanW.isNotEmpty &&
          (cleanW.startsWith(lowerStem) ||
              OfflineAiService.extractConceptStem(cleanW) == lowerStem);

      spans.add(
        TextSpan(
          text: i < words.length - 1 ? '$w ' : w,
          style: isHit
              ? GoogleFonts.literata(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.terracotta,
                  backgroundColor: AppColors.amberGold.withValues(alpha: 0.20),
                )
              : GoogleFonts.literata(
                  fontSize: 13,
                  height: 1.45,
                  color: theme.colorScheme.onSurface,
                ),
        ),
      );
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final res = _result;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.86,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 18 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.amberGold.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.radar_rounded,
                      size: 20,
                      color: AppColors.terracotta,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kitap İçi Kavram Radarı & İndeks',
                          style: GoogleFonts.literata(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Morfolojik kök eşleşmesi ve çapraz bağlam haritası',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Arama Kutusu
              TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: _runSearch,
                style: GoogleFonts.inter(fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'Eserde izini sürmek istediğiniz kavramı yazın...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 19),
                  suffixIcon: IconButton(
                    tooltip: 'Radarı Çalıştır',
                    icon: const Icon(Icons.arrow_forward_rounded, size: 19),
                    onPressed: () => _runSearch(_searchController.text),
                  ),
                  filled: true,
                  fillColor: theme.scaffoldBackgroundColor,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.colorScheme.outline),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Önerilen Sayfa Kavramları
              if (widget.suggestedConcepts.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: widget.suggestedConcepts.map((c) {
                      final isSelected =
                          c.toLowerCase() == _activeConcept.toLowerCase();
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: isSelected
                              ? theme.colorScheme.primary.withValues(alpha: 0.18)
                              : null,
                          label: Text(
                            c,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          onPressed: () {
                            _searchController.text = c;
                            _runSearch(c);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 12),

              if (_isSearching)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (res != null)
                Expanded(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      // 1. Özet İstatistik Kartları
                      Row(
                        children: [
                          Expanded(
                            child: _RadarMetricCard(
                              label: 'TOPLAM GEÇİŞ',
                              value: '${res.totalOccurrences} Kez',
                              subtitle: 'Kök: "${res.stemUsed}-"',
                              icon: Icons.tag_rounded,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _RadarMetricCard(
                              label: 'İLK GEÇİŞ',
                              value: 'Sayfa ${res.firstSeenPage}',
                              subtitle: 'Kavram girişi',
                              icon: Icons.flag_outlined,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _RadarMetricCard(
                              label: 'EN YOĞUN',
                              value: 'Sayfa ${res.peakPage}',
                              subtitle: 'Merkez bölüm',
                              icon: Icons.local_fire_department_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 2. Birlikte Geçen Kavramlar (Kavram Ağı)
                      if (res.relatedConcepts.isNotEmpty) ...[
                        Text(
                          '🔗 BİRLİKTE GEÇEN KAVRAM AĞI (DOKUN & GEÇ)',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: res.relatedConcepts.map((rel) {
                            return ActionChip(
                              avatar: const Icon(Icons.hub_outlined, size: 13),
                              visualDensity: VisualDensity.compact,
                              label: Text(
                                rel,
                                style: const TextStyle(fontSize: 11),
                              ),
                              onPressed: () {
                                _searchController.text = rel;
                                _runSearch(rel);
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 3. Çapraz Cümle Eşleşmeleri (Concordance)
                      Text(
                        '📖 BAĞLAMSAL CÜMLE İNDEKSİ (${res.matches.length} EŞLEŞME)',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (res.matches.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: theme.colorScheme.outline),
                          ),
                          child: Text(
                            'Taranan sayfalarda "$_activeConcept" kavramıyla doğrudan eşleşen cümle bulunamadı.',
                            style: GoogleFonts.inter(fontSize: 12.5),
                          ),
                        )
                      else
                        ...res.matches.map((m) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.scaffoldBackgroundColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary
                                            .withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Sayfa ${m.pageNumber}',
                                        style: GoogleFonts.inter(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () {
                                        Navigator.pop(context);
                                        widget.onJumpToPage(m.pageNumber);
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Sayfaya Git',
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.terracotta,
                                              ),
                                            ),
                                            const SizedBox(width: 3),
                                            const Icon(
                                              Icons.arrow_forward_ios_rounded,
                                              size: 11,
                                              color: AppColors.terracotta,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                RichText(
                                  text: TextSpan(
                                    children: _buildHighlightedSnippetSpans(
                                      m.snippet,
                                      res.stemUsed,
                                      theme,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadarMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final IconData icon;

  const _RadarMetricCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: AppColors.terracotta),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.literata(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}
