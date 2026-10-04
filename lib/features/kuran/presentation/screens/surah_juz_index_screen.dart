import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/surah_data_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/kuran_providers.dart';

class SurahInfo {
  final int id;
  final String name;
  final String arabicName;
  final int verseCount;
  final int page;
  final int cuz;

  const SurahInfo({
    required this.id,
    required this.name,
    required this.arabicName,
    required this.verseCount,
    required this.page,
    required this.cuz,
  });
}

class SurahJuzIndexScreen extends ConsumerStatefulWidget {
  const SurahJuzIndexScreen({super.key});

  @override
  ConsumerState<SurahJuzIndexScreen> createState() => _SurahJuzIndexScreenState();
}

class _SurahJuzIndexScreenState extends ConsumerState<SurahJuzIndexScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  static final List<SurahInfo> surahs = SurahDataProvider.surahs
      .map((s) => SurahInfo(
            id: s.id,
            name: s.name,
            arabicName: s.nameArabic,
            verseCount: s.ayetSayisi,
            page: s.startPage,
            cuz: s.juzNumber,
          ))
      .toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF090D10) : const Color(0xFFF4EFE6);
    final cardBg = isDark ? AppColors.darkCard : const Color(0xFFFFFDF8);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1E2B27);
    final secondaryTextColor = isDark ? const Color(0xFF8A9BAE) : const Color(0xFF6B7280);
    final borderColor = isDark ? AppColors.darkBorder : const Color(0xFFE2DDD2);
    final goldAccent = isDark ? AppColors.gold400 : const Color(0xFFB57D15);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: primaryTextColor),
        title: Text('Kur’ân Fihristi', style: AppTypography.headingSmall(color: primaryTextColor)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: goldAccent,
          labelColor: goldAccent,
          unselectedLabelColor: isDark ? Colors.white60 : const Color(0xFF6B7280),
          tabs: const [
            Tab(text: 'Sûreler (114)'),
            Tab(text: 'Cüzler (30)'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search Box
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              style: TextStyle(color: primaryTextColor),
              decoration: InputDecoration(
                hintText: 'Sûre veya cüz ara...',
                hintStyle: TextStyle(color: secondaryTextColor),
                prefixIcon: Icon(Icons.search, color: goldAccent),
                filled: true,
                fillColor: cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: borderColor),
                ),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSurahList(cardBg, borderColor, primaryTextColor, secondaryTextColor, goldAccent, isDark),
                _buildJuzList(cardBg, borderColor, primaryTextColor, secondaryTextColor, goldAccent, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurahList(Color cardBg, Color borderColor, Color primaryTextColor, Color secondaryTextColor, Color goldAccent, bool isDark) {
    final filtered = surahs.where((s) {
      if (_searchQuery.isEmpty) return true;
      return s.name.toLowerCase().contains(_searchQuery) ||
          s.arabicName.contains(_searchQuery) ||
          s.id.toString() == _searchQuery;
    }).toList();

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final surah = filtered[index];
        return Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: ListTile(
            onTap: () => Navigator.of(context).pop(surah.page),
            leading: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? AppColors.darkBackground : const Color(0xFFF0EBE0),
                border: Border.all(color: goldAccent.withOpacity(0.5)),
              ),
              child: Text(
                '${surah.id}',
                style: TextStyle(
                  color: goldAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    '${surah.name} Sûresi',
                    style: TextStyle(
                      color: primaryTextColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  surah.arabicName,
                  style: TextStyle(
                    fontFamily: ref.watch(arabicFontFamilyProvider),
                    color: goldAccent,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            subtitle: Text(
              '${surah.verseCount} Âyet • ${surah.cuz}. Cüz • Sayfa ${surah.page}',
              style: TextStyle(color: secondaryTextColor, fontSize: 12),
            ),
            trailing: Icon(Icons.arrow_forward_ios_rounded, color: isDark ? Colors.white30 : const Color(0xFF9E9E9E), size: 14),
          ),
        );
      },
    );
  }

  Widget _buildJuzList(Color cardBg, Color borderColor, Color primaryTextColor, Color secondaryTextColor, Color goldAccent, bool isDark) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 30,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final juzNo = index + 1;
        final startPage = (juzNo - 1) * 20 + (juzNo == 1 ? 1 : 2);

        return Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: ListTile(
            onTap: () => Navigator.of(context).pop(startPage),
            leading: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: AppColors.emeraldGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$juzNo',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              '$juzNo. Cüz',
              style: TextStyle(
                color: primaryTextColor,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            subtitle: Text(
              'Başlangıç Sayfası: $startPage',
              style: TextStyle(color: secondaryTextColor, fontSize: 12),
            ),
            trailing: Icon(Icons.arrow_forward_ios_rounded, color: isDark ? Colors.white30 : const Color(0xFF9E9E9E), size: 14),
          ),
        );
      },
    );
  }
}
