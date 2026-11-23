import 'package:flutter/material.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../ocr/domain/ingredient_parser.dart';
import '../../scoring/domain/organic_score_calculator.dart';
import '../../taklit_tagsis/presentation/taklit_tagsis_screen.dart';

class BioArenaScreen extends StatefulWidget {
  const BioArenaScreen({super.key});

  @override
  State<BioArenaScreen> createState() => _BioArenaScreenState();
}

class _BioArenaScreenState extends State<BioArenaScreen> {
  final TextEditingController _ingredientAnalyzerController =
      TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allENumbers = [];
  bool _isLoadingENumbers = true;
  int _selectedFilterIndex = 0; // 0: Tümü, 1: Haram/Kaçınılmalı, 2: Şüpheli Kaynak, 3: Yüksek Sağlık Riski, 4: Güvenli/Doğal

  HalalEvaluationResult? _analyzedHalalResult;
  List<DetectedAdditive> _analyzedAdditives = const [];
  bool _isAnalyzingText = false;

  @override
  void initState() {
    super.initState();
    _loadENumbersFromDb();
  }

  @override
  void dispose() {
    _ingredientAnalyzerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadENumbersFromDb() async {
    try {
      final rows = await DatabaseHelper().getAllENumbers();
      if (mounted) {
        setState(() {
          _allENumbers = rows;
          _isLoadingENumbers = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingENumbers = false);
      }
    }
  }

  Future<void> _analyzeIngredientText(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty) {
      setState(() {
        _analyzedHalalResult = null;
        _analyzedAdditives = const [];
      });
      return;
    }

    setState(() => _isAnalyzingText = true);
    try {
      final parseResult = await IngredientParser.parseIngredients(text);
      final matched = parseResult.additives;
      final halalResult =
          OrganicScoreCalculator.evaluateHalalAndCleanStatus(
        rawIngredients: text,
        matchedAdditives: matched
            .map((a) => (code: a.code, name: a.name, category: a.category))
            .toList(),
      );
      if (mounted) {
        setState(() {
          _analyzedAdditives = matched;
          _analyzedHalalResult = halalResult;
          _isAnalyzingText = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isAnalyzingText = false);
    }
  }

  String _classifyHalalTag(Map<String, dynamic> row) {
    final String category = (row['category'] as String? ?? '').toUpperCase();
    if (category.contains('HARAM')) return 'HARAM';
    if (category.contains('ŞÜPHELİ') || category.contains('SERTİFİKASI ŞART')) {
      return 'SUPHELI';
    }
    return 'HELAL';
  }

  List<Map<String, dynamic>> get _filteredENumbers {
    final String q = _searchController.text.trim().toLowerCase();
    return _allENumbers.where((row) {
      final String code = (row['code'] as String? ?? '').toLowerCase();
      final String name = (row['name'] as String? ?? '').toLowerCase();
      final String desc = (row['category'] as String? ?? '').toLowerCase();
      final String hazards =
          (row['health_hazards'] as String? ?? '').toLowerCase();
      final String risk = (row['risk_level'] as String? ?? 'MODERATE');
      final String halalTag = _classifyHalalTag(row);

      if (q.isNotEmpty &&
          !code.contains(q) &&
          !name.contains(q) &&
          !desc.contains(q) &&
          !hazards.contains(q)) {
        return false;
      }

      switch (_selectedFilterIndex) {
        case 1: // Haram / Kaçınılmalı
          return halalTag == 'HARAM' || risk == 'TOXIC';
        case 2: // Şüpheli (Kaynak Sorulmalı)
          return halalTag == 'SUPHELI';
        case 3: // Yüksek Sağlık Riski
          return risk == 'HIGH' || risk == 'TOXIC';
        case 4: // Helal & Düşük Risk
          return halalTag == 'HELAL' && risk == 'LOW';
        default:
          return true;
      }
    }).toList();
  }

  Color _riskColor(String risk) {
    switch (risk) {
      case 'TOXIC':
        return AppColors.dangerRed;
      case 'HIGH':
        return const Color(0xFFEA580C);
      case 'MODERATE':
        return AppColors.cautionGold;
      case 'LOW':
        return AppColors.primaryEmerald;
      default:
        return AppColors.cautionGold;
    }
  }

  String _riskLabelTr(String risk) {
    switch (risk) {
      case 'TOXIC':
        return 'Çok Yüksek Risk';
      case 'HIGH':
        return 'Yüksek Risk';
      case 'MODERATE':
        return 'Orta Risk';
      case 'LOW':
        return 'Düşük Risk / Güvenli';
      default:
        return risk;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;
    final filteredList = _filteredENumbers;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BioMinimalUi.sectionHeader(
            context,
            overline: 'HELAL & TEMİZ İÇERİK SÖZLÜĞÜ',
            title: 'Helal & E-Kod Rehberi',
            trailing: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TaklitTagsisScreen(),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.dangerRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.dangerRed.withValues(alpha: 0.35),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.gavel_rounded,
                      size: 13,
                      color: AppColors.dangerRed,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Bakanlık İfşa',
                      style: TextStyle(
                        color: AppColors.dangerRed,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // =========================================================================
          // 1. LIVE INGREDIENT TEXT HALAL & CLEAN LABEL ANALYZER
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
                    const Icon(
                      Icons.menu_book_rounded,
                      color: AppColors.primaryEmerald,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Canlı İçindekiler Metni Denetleyici',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Paket üzerindeki içindekiler listesini aşağıya yazın veya yapıştırın; Helal açısından kritik/şüpheli bileşenleri ve E-kodlarını anında analiz edelim.',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _ingredientAnalyzerController,
                  maxLines: 2,
                  style: TextStyle(color: textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText:
                        'Örn: Şeker, glikoz şurubu, sığır jelatini, E120 karmin, emülgatör (E471), aroma verici...',
                    hintStyle: TextStyle(
                      color: textSecondary.withValues(alpha: 0.75),
                      fontSize: 12,
                    ),
                    filled: true,
                    fillColor: context.subtleSurfaceColor,
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Quick Example Pills + Analyze Button
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildQuickSampleButton(
                              'Örnek: Jelibon / Şekerleme',
                              'Glikoz şurubu, şeker, yenilebilir jelatin (E441), sitrik asit (E330), renklendirici (E120 karmin), parlatıcı (E904 şellak), aroma verici.',
                            ),
                            const SizedBox(width: 6),
                            _buildQuickSampleButton(
                              'Örnek: Paketli Kek',
                              'Buğday unu, şeker, bitkisel yağ (palm), emülgatör (E471 mono ve digliseridler, E472e), koruyucu (E202), aroma verici.',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isAnalyzingText
                          ? null
                          : () => _analyzeIngredientText(
                                _ingredientAnalyzerController.text,
                              ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryEmerald,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Denetle',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),

                if (_analyzedHalalResult != null) ...[
                  const SizedBox(height: 14),
                  _buildAnalyzedResultBanner(context, _analyzedHalalResult!),
                ],
              ],
            ),
          ),

          const SizedBox(height: 22),

          // =========================================================================
          // 2. SEARCHABLE E-CODE & HALAL ADDITIVE DICTIONARY
          // =========================================================================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'E-Kodları & Katkı Maddeleri (${filteredList.length})',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'EFSA & Helal Fıkıh Rehberi',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Search Box
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            style: TextStyle(color: textPrimary, fontSize: 13.5),
            decoration: InputDecoration(
              hintText: 'E-kodu veya madde ara (örn. E120, E471, Jelatin, MSG)...',
              hintStyle: TextStyle(color: textSecondary, fontSize: 12.5),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.primaryEmerald,
                size: 20,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear_rounded,
                        size: 18,
                        color: textSecondary,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              filled: true,
              fillColor: context.surfaceColor,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: context.cardBorderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.primaryEmerald),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCategoryChip(0, 'Tümü (${_allENumbers.length})'),
                const SizedBox(width: 8),
                _buildCategoryChip(1, '⛔ Haram / Kaçınılmalı'),
                const SizedBox(width: 8),
                _buildCategoryChip(2, '⚠️ Şüpheli (Kaynak Sorulmalı)'),
                const SizedBox(width: 8),
                _buildCategoryChip(3, '🚨 Yüksek Sağlık Riski'),
                const SizedBox(width: 8),
                _buildCategoryChip(4, '✅ Helal & Güvenli'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (_isLoadingENumbers)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(
                  color: AppColors.primaryEmerald,
                ),
              ),
            )
          else if (filteredList.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BioMinimalUi.cardDecoration(context),
              child: Text(
                'Aranan kriterlere uygun E-kodu bulunamadı.',
                style: TextStyle(color: textSecondary, fontSize: 13),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredList.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final row = filteredList[index];
                final String code = row['code'] as String? ?? '';
                final String name = row['name'] as String? ?? '';
                final String risk = row['risk_level'] as String? ?? 'MODERATE';
                final String desc = row['category'] as String? ?? '';
                final String impact = row['health_hazards'] as String? ?? '';
                final String halalTag = _classifyHalalTag(row);
                final Color rColor = _riskColor(risk);

                Color halalBadgeColor = AppColors.primaryEmerald;
                String halalBadgeText = 'Helal Açıdan Uygun';
                if (halalTag == 'HARAM') {
                  halalBadgeColor = AppColors.dangerRed;
                  halalBadgeText = 'Haram / Kaçınılmalı';
                } else if (halalTag == 'SUPHELI') {
                  halalBadgeColor = AppColors.cautionGold;
                  halalBadgeText = 'Şüpheli (Kaynak Sorulmalı)';
                }

                return Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BioMinimalUi.cardDecoration(context, radius: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: rColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: rColor.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              code,
                              style: TextStyle(
                                color: rColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                color: textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: halalBadgeColor.withValues(alpha: 0.13),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              halalBadgeText,
                              style: TextStyle(
                                color: halalBadgeColor,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: rColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Sağlık: ${_riskLabelTr(risk)}',
                              style: TextStyle(
                                color: rColor,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        desc,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        impact,
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildQuickSampleButton(String label, String sampleText) {
    return GestureDetector(
      onTap: () {
        _ingredientAnalyzerController.text = sampleText;
        _analyzeIngredientText(sampleText);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: context.subtleSurfaceColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.cardBorderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: context.textSecondaryColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyzedResultBanner(
    BuildContext context,
    HalalEvaluationResult result,
  ) {
    Color statusColor = AppColors.primaryEmerald;
    IconData statusIcon = Icons.verified_rounded;
    if (result.status == HalalStatusLevel.haramRisk) {
      statusColor = AppColors.dangerRed;
      statusIcon = Icons.gpp_bad_rounded;
    } else if (result.status == HalalStatusLevel.doubtful) {
      statusColor = AppColors.cautionGold;
      statusIcon = Icons.warning_amber_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.badgeLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            result.summary,
            style: TextStyle(
              color: context.textPrimaryColor,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          if (result.haramFindings.isNotEmpty ||
              result.doubtfulFindings.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...result.haramFindings.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '⛔ ${f.title}: ${f.reason}',
                  style: const TextStyle(
                    color: AppColors.dangerRed,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            ...result.doubtfulFindings.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '⚠️ ${f.title}: ${f.reason}',
                  style: TextStyle(
                    color: context.textPrimaryColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
          if (_analyzedAdditives.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Tespit Edilen E-Kodları (${_analyzedAdditives.length}): ${_analyzedAdditives.map((a) => "${a.code} (${a.name})").join(", ")}',
              style: TextStyle(
                color: context.textSecondaryColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryChip(int index, String label) {
    final bool selected = _selectedFilterIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilterIndex = index),
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
}
