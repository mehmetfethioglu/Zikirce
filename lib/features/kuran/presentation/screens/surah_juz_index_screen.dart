import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  static const List<SurahInfo> surahs = [
    SurahInfo(id: 1, name: 'Fâtiha', arabicName: 'الفاتحة', verseCount: 7, page: 1, cuz: 1),
    SurahInfo(id: 2, name: 'Bakara', arabicName: 'البقرة', verseCount: 286, page: 2, cuz: 1),
    SurahInfo(id: 3, name: 'Âl-i İmrân', arabicName: 'آل عمران', verseCount: 200, page: 50, cuz: 3),
    SurahInfo(id: 4, name: 'Nisâ', arabicName: 'النساء', verseCount: 176, page: 77, cuz: 4),
    SurahInfo(id: 5, name: 'Mâide', arabicName: 'المائدة', verseCount: 120, page: 106, cuz: 6),
    SurahInfo(id: 6, name: 'En\'âm', arabicName: 'الأنعام', verseCount: 165, page: 128, cuz: 7),
    SurahInfo(id: 7, name: 'A\'râf', arabicName: 'الأعراف', verseCount: 206, page: 151, cuz: 8),
    SurahInfo(id: 8, name: 'Enfâl', arabicName: 'الأنفال', verseCount: 75, page: 177, cuz: 9),
    SurahInfo(id: 9, name: 'Tevbe', arabicName: 'التوبة', verseCount: 129, page: 187, cuz: 10),
    SurahInfo(id: 10, name: 'Yûnus', arabicName: 'يونس', verseCount: 109, page: 208, cuz: 11),
    SurahInfo(id: 11, name: 'Hûd', arabicName: 'هود', verseCount: 123, page: 221, cuz: 11),
    SurahInfo(id: 12, name: 'Yûsuf', arabicName: 'يوسف', verseCount: 111, page: 235, cuz: 12),
    SurahInfo(id: 13, name: 'Ra\'d', arabicName: 'الرعد', verseCount: 43, page: 249, cuz: 13),
    SurahInfo(id: 14, name: 'İbrâhîm', arabicName: 'إبراهيم', verseCount: 52, page: 255, cuz: 13),
    SurahInfo(id: 15, name: 'Hicr', arabicName: 'الحجر', verseCount: 99, page: 262, cuz: 14),
    SurahInfo(id: 16, name: 'Nahl', arabicName: 'النحل', verseCount: 128, page: 267, cuz: 14),
    SurahInfo(id: 17, name: 'İsrâ', arabicName: 'الإسراء', verseCount: 111, page: 282, cuz: 15),
    SurahInfo(id: 18, name: 'Kehf', arabicName: 'الكهف', verseCount: 110, page: 293, cuz: 15),
    SurahInfo(id: 19, name: 'Meryem', arabicName: 'مريم', verseCount: 98, page: 305, cuz: 16),
    SurahInfo(id: 20, name: 'Tâhâ', arabicName: 'طه', verseCount: 135, page: 312, cuz: 16),
    SurahInfo(id: 21, name: 'Enbiyâ', arabicName: 'الأنبياء', verseCount: 112, page: 322, cuz: 17),
    SurahInfo(id: 22, name: 'Hac', arabicName: 'الحج', verseCount: 78, page: 332, cuz: 17),
    SurahInfo(id: 23, name: 'Mü\'minûn', arabicName: 'المؤمنون', verseCount: 118, page: 342, cuz: 18),
    SurahInfo(id: 24, name: 'Nûr', arabicName: 'النور', verseCount: 64, page: 350, cuz: 18),
    SurahInfo(id: 25, name: 'Furkân', arabicName: 'الفرقان', verseCount: 77, page: 359, cuz: 18),
    SurahInfo(id: 26, name: 'Şuarâ', arabicName: 'الشعراء', verseCount: 227, page: 367, cuz: 19),
    SurahInfo(id: 27, name: 'Neml', arabicName: 'النمل', verseCount: 93, page: 377, cuz: 19),
    SurahInfo(id: 28, name: 'Kasas', arabicName: 'القصص', verseCount: 88, page: 385, cuz: 20),
    SurahInfo(id: 29, name: 'Ankebût', arabicName: 'العنكبوت', verseCount: 69, page: 396, cuz: 20),
    SurahInfo(id: 30, name: 'Rûm', arabicName: 'الروم', verseCount: 60, page: 404, cuz: 21),
    SurahInfo(id: 31, name: 'Lokmân', arabicName: 'لقمان', verseCount: 34, page: 411, cuz: 21),
    SurahInfo(id: 32, name: 'Secde', arabicName: 'السجدة', verseCount: 30, page: 415, cuz: 21),
    SurahInfo(id: 33, name: 'Ahzâb', arabicName: 'الأحزاب', verseCount: 73, page: 418, cuz: 21),
    SurahInfo(id: 34, name: 'Sebe\'', arabicName: 'سبإ', verseCount: 54, page: 428, cuz: 22),
    SurahInfo(id: 35, name: 'Fâtır', arabicName: 'فاطر', verseCount: 45, page: 434, cuz: 22),
    SurahInfo(id: 36, name: 'Yâsîn', arabicName: 'يس', verseCount: 83, page: 440, cuz: 22),
    SurahInfo(id: 37, name: 'Sâffât', arabicName: 'الصافات', verseCount: 182, page: 446, cuz: 23),
    SurahInfo(id: 38, name: 'Sâd', arabicName: 'ص', verseCount: 88, page: 453, cuz: 23),
    SurahInfo(id: 39, name: 'Zümer', arabicName: 'الزمر', verseCount: 75, page: 458, cuz: 23),
    SurahInfo(id: 40, name: 'Mü\'min (Gâfir)', arabicName: 'غافر', verseCount: 85, page: 467, cuz: 24),
    SurahInfo(id: 41, name: 'Fussilet', arabicName: 'فصلت', verseCount: 54, page: 477, cuz: 24),
    SurahInfo(id: 42, name: 'Şûrâ', arabicName: 'الشورى', verseCount: 53, page: 483, cuz: 25),
    SurahInfo(id: 43, name: 'Zuhruf', arabicName: 'الزخرف', verseCount: 89, page: 489, cuz: 25),
    SurahInfo(id: 44, name: 'Duhân', arabicName: 'الدخان', verseCount: 59, page: 496, cuz: 25),
    SurahInfo(id: 45, name: 'Câsiye', arabicName: 'الجاثية', verseCount: 37, page: 499, cuz: 25),
    SurahInfo(id: 46, name: 'Ahkâf', arabicName: 'الأحقاف', verseCount: 35, page: 502, cuz: 26),
    SurahInfo(id: 47, name: 'Muhammed', arabicName: 'محمد', verseCount: 38, page: 507, cuz: 26),
    SurahInfo(id: 48, name: 'Fetih', arabicName: 'الفتح', verseCount: 29, page: 511, cuz: 26),
    SurahInfo(id: 49, name: 'Hucurât', arabicName: 'الحجرات', verseCount: 18, page: 515, cuz: 26),
    SurahInfo(id: 50, name: 'Kâf', arabicName: 'ق', verseCount: 45, page: 518, cuz: 26),
    SurahInfo(id: 51, name: 'Zâriyât', arabicName: 'الذاريات', verseCount: 60, page: 520, cuz: 26),
    SurahInfo(id: 52, name: 'Tûr', arabicName: 'الطور', verseCount: 49, page: 523, cuz: 27),
    SurahInfo(id: 53, name: 'Necm', arabicName: 'النجم', verseCount: 62, page: 526, cuz: 27),
    SurahInfo(id: 54, name: 'Kamer', arabicName: 'القمر', verseCount: 55, page: 528, cuz: 27),
    SurahInfo(id: 55, name: 'Rahmân', arabicName: 'الرحمن', verseCount: 78, page: 531, cuz: 27),
    SurahInfo(id: 56, name: 'Vâkıa', arabicName: 'الواقعة', verseCount: 96, page: 534, cuz: 27),
    SurahInfo(id: 57, name: 'Hadîd', arabicName: 'الحديد', verseCount: 29, page: 537, cuz: 27),
    SurahInfo(id: 58, name: 'Mücâdele', arabicName: 'المجادلة', verseCount: 22, page: 542, cuz: 28),
    SurahInfo(id: 59, name: 'Haşr', arabicName: 'الحشر', verseCount: 24, page: 545, cuz: 28),
    SurahInfo(id: 60, name: 'Mümtehine', arabicName: 'الممتحنة', verseCount: 13, page: 549, cuz: 28),
    SurahInfo(id: 61, name: 'Saff', arabicName: 'الصف', verseCount: 14, page: 551, cuz: 28),
    SurahInfo(id: 62, name: 'Cuma', arabicName: 'الجمعة', verseCount: 11, page: 553, cuz: 28),
    SurahInfo(id: 63, name: 'Münâfikûn', arabicName: 'المنافقون', verseCount: 11, page: 554, cuz: 28),
    SurahInfo(id: 64, name: 'Teğâbün', arabicName: 'التغابن', verseCount: 18, page: 556, cuz: 28),
    SurahInfo(id: 65, name: 'Talâk', arabicName: 'الطلاق', verseCount: 12, page: 558, cuz: 28),
    SurahInfo(id: 66, name: 'Tahrîm', arabicName: 'التحريم', verseCount: 12, page: 560, cuz: 28),
    SurahInfo(id: 67, name: 'Mülk', arabicName: 'الملك', verseCount: 30, page: 562, cuz: 29),
    SurahInfo(id: 68, name: 'Kalem', arabicName: 'القلم', verseCount: 52, page: 564, cuz: 29),
    SurahInfo(id: 69, name: 'Hâkka', arabicName: 'الحاقة', verseCount: 52, page: 566, cuz: 29),
    SurahInfo(id: 70, name: 'Meâric', arabicName: 'المعارج', verseCount: 44, page: 568, cuz: 29),
    SurahInfo(id: 71, name: 'Nûh', arabicName: 'نوح', verseCount: 28, page: 570, cuz: 29),
    SurahInfo(id: 72, name: 'Cin', arabicName: 'الجن', verseCount: 28, page: 572, cuz: 29),
    SurahInfo(id: 73, name: 'Müzzemmil', arabicName: 'المزمل', verseCount: 20, page: 574, cuz: 29),
    SurahInfo(id: 74, name: 'Müddessir', arabicName: 'المدثر', verseCount: 56, page: 575, cuz: 29),
    SurahInfo(id: 75, name: 'Kıyâme', arabicName: 'القيامة', verseCount: 40, page: 577, cuz: 29),
    SurahInfo(id: 76, name: 'İnsân', arabicName: 'الإنسان', verseCount: 31, page: 578, cuz: 29),
    SurahInfo(id: 77, name: 'Mürselât', arabicName: 'المرسلات', verseCount: 50, page: 580, cuz: 29),
    SurahInfo(id: 78, name: 'Nebe\'', arabicName: 'النبإ', verseCount: 40, page: 582, cuz: 30),
    SurahInfo(id: 79, name: 'Nâziât', arabicName: 'النازعات', verseCount: 46, page: 583, cuz: 30),
    SurahInfo(id: 80, name: 'Abese', arabicName: 'عبس', verseCount: 42, page: 585, cuz: 30),
    SurahInfo(id: 81, name: 'Tekvîr', arabicName: 'التكوير', verseCount: 29, page: 586, cuz: 30),
    SurahInfo(id: 82, name: 'İnfitâr', arabicName: 'الانفطار', verseCount: 19, page: 587, cuz: 30),
    SurahInfo(id: 83, name: 'Mutaffifîn', arabicName: 'المطففين', verseCount: 36, page: 587, cuz: 30),
    SurahInfo(id: 84, name: 'İnşikâk', arabicName: 'الانشقاق', verseCount: 25, page: 589, cuz: 30),
    SurahInfo(id: 85, name: 'Bürûc', arabicName: 'البروج', verseCount: 22, page: 590, cuz: 30),
    SurahInfo(id: 86, name: 'Târık', arabicName: 'الطارق', verseCount: 17, page: 591, cuz: 30),
    SurahInfo(id: 87, name: 'A\'lâ', arabicName: 'الأعلى', verseCount: 19, page: 591, cuz: 30),
    SurahInfo(id: 88, name: 'Gâşiye', arabicName: 'الغاشية', verseCount: 26, page: 592, cuz: 30),
    SurahInfo(id: 89, name: 'Fecr', arabicName: 'الفجر', verseCount: 30, page: 593, cuz: 30),
    SurahInfo(id: 90, name: 'Beled', arabicName: 'البلد', verseCount: 20, page: 594, cuz: 30),
    SurahInfo(id: 91, name: 'Şems', arabicName: 'الشمس', verseCount: 15, page: 595, cuz: 30),
    SurahInfo(id: 92, name: 'Leyl', arabicName: 'الليل', verseCount: 21, page: 595, cuz: 30),
    SurahInfo(id: 93, name: 'Duhâ', arabicName: 'الضحى', verseCount: 11, page: 596, cuz: 30),
    SurahInfo(id: 94, name: 'İnşirâh', arabicName: 'الشرح', verseCount: 8, page: 596, cuz: 30),
    SurahInfo(id: 95, name: 'Tîn', arabicName: 'التين', verseCount: 8, page: 597, cuz: 30),
    SurahInfo(id: 96, name: 'Alak', arabicName: 'العلق', verseCount: 19, page: 597, cuz: 30),
    SurahInfo(id: 97, name: 'Kadir', arabicName: 'القدر', verseCount: 5, page: 598, cuz: 30),
    SurahInfo(id: 98, name: 'Beyyine', arabicName: 'البينة', verseCount: 8, page: 598, cuz: 30),
    SurahInfo(id: 99, name: 'Zilzâl', arabicName: 'الزلزلة', verseCount: 8, page: 599, cuz: 30),
    SurahInfo(id: 100, name: 'Âdiyât', arabicName: 'العاديات', verseCount: 11, page: 599, cuz: 30),
    SurahInfo(id: 101, name: 'Kâria', arabicName: 'القارعة', verseCount: 11, page: 600, cuz: 30),
    SurahInfo(id: 102, name: 'Tekâsür', arabicName: 'التكاثر', verseCount: 8, page: 600, cuz: 30),
    SurahInfo(id: 103, name: 'Asr', arabicName: 'العصر', verseCount: 3, page: 601, cuz: 30),
    SurahInfo(id: 104, name: 'Hümeze', arabicName: 'الهمزة', verseCount: 9, page: 601, cuz: 30),
    SurahInfo(id: 105, name: 'Fîl', arabicName: 'الفيل', verseCount: 5, page: 601, cuz: 30),
    SurahInfo(id: 106, name: 'Kureyş', arabicName: 'قريش', verseCount: 4, page: 602, cuz: 30),
    SurahInfo(id: 107, name: 'Mâûn', arabicName: 'الماعون', verseCount: 7, page: 602, cuz: 30),
    SurahInfo(id: 108, name: 'Kevser', arabicName: 'الكوثر', verseCount: 3, page: 602, cuz: 30),
    SurahInfo(id: 109, name: 'Kâfirûn', arabicName: 'الكافرون', verseCount: 6, page: 603, cuz: 30),
    SurahInfo(id: 110, name: 'Nasr', arabicName: 'النصر', verseCount: 3, page: 603, cuz: 30),
    SurahInfo(id: 111, name: 'Mesed (Tebbet)', arabicName: 'المسد', verseCount: 5, page: 603, cuz: 30),
    SurahInfo(id: 112, name: 'İhlâs', arabicName: 'الإخلاص', verseCount: 4, page: 604, cuz: 30),
    SurahInfo(id: 113, name: 'Felak', arabicName: 'الفلق', verseCount: 5, page: 604, cuz: 30),
    SurahInfo(id: 114, name: 'Nâs', arabicName: 'الناس', verseCount: 6, page: 604, cuz: 30),
  ];

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
