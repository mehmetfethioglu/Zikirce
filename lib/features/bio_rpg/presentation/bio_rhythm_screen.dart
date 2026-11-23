import 'package:flutter/material.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../product/presentation/product_result_screen.dart';
import '../domain/bio_rpg_models.dart';
import '../domain/bio_rpg_service.dart';

class BioRhythmScreen extends StatefulWidget {
  const BioRhythmScreen({super.key});

  @override
  State<BioRhythmScreen> createState() => _BioRhythmScreenState();
}

class _BioRhythmScreenState extends State<BioRhythmScreen> {
  List<Map<String, dynamic>> _sqliteHistory = [];
  bool _isLoadingHistory = true;
  int _selectedFilter = 0; // 0: Tüm Tarananlar, 1: Tükettiklerim, 2: Rafa Bıraktıklarım

  @override
  void initState() {
    super.initState();
    _loadSqliteHistory();
  }

  Future<void> _loadSqliteHistory() async {
    try {
      final rows = await DatabaseHelper().getScanHistory(limit: 50);
      if (mounted) {
        setState(() {
          _sqliteHistory = rows;
          _isLoadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingHistory = false);
      }
    }
  }

  Future<void> _clearAllHistory() async {
    await DatabaseHelper().clearProductHistory();
    await BioRpgService.instance.clearScanHistory();
    await _loadSqliteHistory();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tarama ve tüketim günlüğü temizlendi.'),
        backgroundColor: AppColors.primaryEmerald,
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 80) return AppColors.primaryEmerald;
    if (score >= 60) return AppColors.primaryMint;
    if (score >= 40) return AppColors.cautionGold;
    return AppColors.dangerRed;
  }

  String _formatTimestamp(int epochMs) {
    if (epochMs <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMs);
    final String day = dt.day.toString().padLeft(2, '0');
    final String month = dt.month.toString().padLeft(2, '0');
    final String hour = dt.hour.toString().padLeft(2, '0');
    final String min = dt.minute.toString().padLeft(2, '0');
    return '$day.$month.${dt.year} $hour:$min';
  }

  @override
  Widget build(BuildContext context) {
    final textSecondary = context.textSecondaryColor;

    return ValueListenableBuilder<PersonalOrganicScoreState>(
      valueListenable: BioRpgService.instance,
      builder: (context, state, _) {
        final List<MetabolicScanRecord> decisions = state.scanHistory;
        final List<MetabolicScanRecord> consumedList = decisions
            .where((d) => d.decision == ScanDecisionType.consumed)
            .toList();
        final List<MetabolicScanRecord> rejectedList = decisions
            .where((d) => d.decision == ScanDecisionType.rejected)
            .toList();

        // Compute real average score from consumed items (or from SQLite history if no explicit decision yet)
        int? realAverageScore;
        if (consumedList.isNotEmpty) {
          realAverageScore = (consumedList
                      .map((e) => e.productScore)
                      .reduce((a, b) => a + b) /
                  consumedList.length)
              .round();
        } else if (_sqliteHistory.isNotEmpty) {
          final validScores = _sqliteHistory
              .map((r) => (r['organicscore'] as num?)?.toInt() ?? -1)
              .where((s) => s >= 0)
              .toList();
          if (validScores.isNotEmpty) {
            realAverageScore =
                (validScores.reduce((a, b) => a + b) / validScores.length)
                    .round();
          }
        }

        final int naturalCount = _sqliteHistory
            .where((r) => ((r['nova_group'] as num?)?.toInt() ?? 3) <= 2)
            .length;
        final int ultraProcessedCount = _sqliteHistory
            .where((r) => ((r['nova_group'] as num?)?.toInt() ?? 3) == 4)
            .length;

        return RefreshIndicator(
          color: AppColors.primaryEmerald,
          onRefresh: _loadSqliteHistory,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BioMinimalUi.sectionHeader(
                  context,
                  overline: 'GERÇEK TÜKETİM & TARAMA VERİLERİ',
                  title: 'Beslenme Günlüğüm',
                  trailing: (_sqliteHistory.isNotEmpty || decisions.isNotEmpty)
                      ? GestureDetector(
                          onTap: _clearAllHistory,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: context.subtleSurfaceColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Temizle',
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 16),

                // =========================================================================
                // 1. REAL METRICS SUMMARY CARD (ZERO FAKE VALUES)
                // =========================================================================
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BioMinimalUi.cardDecoration(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatBox(
                              context,
                              label: 'Taranan Ürün',
                              value: '${_sqliteHistory.length}',
                              subtitle: 'SQLite Geçmişi',
                              accent: AppColors.primaryEmerald,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildStatBox(
                              context,
                              label: 'Ort. Gıda Skoru',
                              value: realAverageScore != null
                                  ? '$realAverageScore/100'
                                  : '—',
                              subtitle: consumedList.isNotEmpty
                                  ? '${consumedList.length} tüketilen ürün'
                                  : 'Taranan ortalaması',
                              accent: realAverageScore != null
                                  ? _scoreColor(realAverageScore)
                                  : textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatBox(
                              context,
                              label: 'Rafa Bırakılan',
                              value: '${rejectedList.length}',
                              subtitle: 'Kaçınılan riskli ürün',
                              accent: AppColors.primaryMint,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildStatBox(
                              context,
                              label: 'Doğal vs NOVA 4',
                              value: '$naturalCount / $ultraProcessedCount',
                              subtitle: 'Doğal / Ultra-İşlenmiş',
                              accent: ultraProcessedCount > naturalCount
                                  ? AppColors.cautionGold
                                  : AppColors.primaryEmerald,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // =========================================================================
                // 2. FILTER PILLS FOR LOGGED ITEMS
                // =========================================================================
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        0,
                        'Taranan Ürünler (${_sqliteHistory.length})',
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        1,
                        'Tükettiklerim (${consumedList.length})',
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        2,
                        'Rafa Bıraktıklarım (${rejectedList.length})',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // =========================================================================
                // 3. CHRONOLOGICAL REAL HISTORY LIST
                // =========================================================================
                if (_isLoadingHistory)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(
                        color: AppColors.primaryEmerald,
                      ),
                    ),
                  )
                else if (_selectedFilter == 0)
                  _buildSqliteHistoryList(context)
                else if (_selectedFilter == 1)
                  _buildDecisionList(
                    context,
                    consumedList,
                    emptyText:
                        'Henüz "Tükettim" olarak işaretlediğiniz bir ürün yok. Ürün inceleme ekranında tüketim tercihinizi kaydedebilirsiniz.',
                  )
                else
                  _buildDecisionList(
                    context,
                    rejectedList,
                    emptyText:
                        'Henüz "Rafa Bıraktım / Vazgeçtim" olarak işaretlediğiniz bir ürün yok.',
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatBox(
    BuildContext context, {
    required String label,
    required String value,
    required String subtitle,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: context.subtleSurfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: context.textSecondaryColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: context.textSecondaryColor,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(int index, String label) {
    final bool selected = _selectedFilter == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryEmerald.withValues(alpha: 0.15)
              : context.subtleSurfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? AppColors.primaryEmerald
                : context.cardBorderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? AppColors.primaryEmerald
                : context.textSecondaryColor,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildSqliteHistoryList(BuildContext context) {
    if (_sqliteHistory.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BioMinimalUi.cardDecoration(context),
        child: Column(
          children: [
            Icon(
              Icons.qr_code_scanner_rounded,
              size: 36,
              color: context.textSecondaryColor,
            ),
            const SizedBox(height: 10),
            Text(
              'Henüz Taranmış Ürün Yok',
              style: TextStyle(
                color: context.textPrimaryColor,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Barkod okuttuğunuz veya katalogdan incelediğiniz tüm gıdalar gerçek skorları ve NOVA sınıflarıyla burada listelenir.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.textSecondaryColor,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _sqliteHistory.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final row = _sqliteHistory[index];
        final String barcode = row['barcode'] as String? ?? '';
        final String name = row['product_name'] as String? ?? 'Ürün';
        final String brand = row['brand'] as String? ?? '';
        final int score = (row['organicscore'] as num?)?.toInt() ?? 50;
        final int nova = (row['nova_group'] as num?)?.toInt() ?? 3;
        final int scannedAt = (row['scanned_at'] as num?)?.toInt() ?? 0;
        final Color sColor = _scoreColor(score);

        return GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductResultScreen(
                  barcode: barcode,
                  ingredientsOcrText: null,
                ),
              ),
            );
            _loadSqliteHistory();
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BioMinimalUi.cardDecoration(context, radius: 18),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: sColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Center(
                    child: Text(
                      '$score',
                      style: TextStyle(
                        color: sColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: context.textPrimaryColor,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${brand.isNotEmpty ? "$brand • " : ""}NOVA $nova • ${_formatTimestamp(scannedAt)}',
                        style: TextStyle(
                          color: context.textSecondaryColor,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.textSecondaryColor,
                  size: 18,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDecisionList(
    BuildContext context,
    List<MetabolicScanRecord> records, {
    required String emptyText,
  }) {
    if (records.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BioMinimalUi.cardDecoration(context),
        child: Text(
          emptyText,
          style: TextStyle(
            color: context.textSecondaryColor,
            fontSize: 12.5,
            height: 1.4,
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: records.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = records[index];
        final Color sColor = _scoreColor(item.productScore);
        final bool isConsumed = item.decision == ScanDecisionType.consumed;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductResultScreen(
                  barcode: item.barcode,
                  ingredientsOcrText: null,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BioMinimalUi.cardDecoration(context, radius: 18),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: sColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '${item.productScore}',
                      style: TextStyle(
                        color: sColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: TextStyle(
                          color: context.textPrimaryColor,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${isConsumed ? "Tüketildi" : "Rafa Bırakıldı"} • ${_formatTimestamp(item.timestamp)}',
                        style: TextStyle(
                          color: isConsumed
                              ? context.textSecondaryColor
                              : AppColors.primaryEmerald,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.textSecondaryColor,
                  size: 18,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
