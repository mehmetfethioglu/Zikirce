import 'package:flutter/material.dart';
import '../../../../core/constants/surah_data_provider.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../gamification/models/badge_models.dart';
import 'add_custom_quran_badge_sheet.dart';

/// Hatim ve Mukabele Detay & İstatistik Bottom Sheet'i
class HatimDetailBottomSheet extends StatelessWidget {
  final Hatim hatim;
  final int currentPage;
  final int progressPercent;
  final int todayPages;
  final DateTime? lastReadDate;
  final bool isMukabele;
  final Color accentColor;
  final VoidCallback onContinue;

  const HatimDetailBottomSheet({
    super.key,
    required this.hatim,
    required this.currentPage,
    required this.progressPercent,
    required this.todayPages,
    required this.lastReadDate,
    required this.isMukabele,
    required this.accentColor,
    required this.onContinue,
  });

  static Future<void> show({
    required BuildContext context,
    required Hatim hatim,
    required int currentPage,
    required int progressPercent,
    required int todayPages,
    required DateTime? lastReadDate,
    required bool isMukabele,
    required Color accentColor,
    required VoidCallback onContinue,
  }) {
    HapticService.selectionClick();
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HatimDetailBottomSheet(
        hatim: hatim,
        currentPage: currentPage,
        progressPercent: progressPercent,
        todayPages: todayPages,
        lastReadDate: lastReadDate,
        isMukabele: isMukabele,
        accentColor: accentColor,
        onContinue: onContinue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E2128) : Colors.white;
    final primaryTextColor = isDark ? const Color(0xFFE8DDD0) : const Color(0xFF1E2B27);
    final secondaryTextColor = isDark ? const Color(0xFFA89888) : const Color(0xFF506861);
    final surfaceBg = isDark ? const Color(0xFF272C35) : const Color(0xFFF3F7F5);
    final borderStroke = isDark ? const Color(0xFF353C48) : const Color(0xFFDEE9E5);

    final completedPages = hatim.completedPages.clamp(0, 604);
    final remainingPages = (604 - completedPages).clamp(0, 604);
    final currentJuz = SurahDataProvider.getJuzForPage(currentPage);
    final juzStart = SurahDataProvider.getJuzStartPage(currentJuz);
    final pageInJuz = (currentPage - juzStart + 1).clamp(1, 20);

    // Tahmini bitiş
    String? estimatedFinishText;
    if (remainingPages == 0) {
      estimatedFinishText = 'Hatm-i Şerif Tamamlandı! 🎉';
    } else if (todayPages > 0) {
      final daysLeft = (remainingPages / todayPages).ceil();
      estimatedFinishText = 'Bu tempoyla (~$todayPages s/gün): $daysLeft gün kaldı';
    } else if (hatim.targetDate != null) {
      final daysLeft = hatim.targetDate!.difference(DateTime.now()).inDays;
      if (daysLeft > 0) {
        final neededPerDay = (remainingPages / daysLeft).ceil();
        estimatedFinishText = 'Hedefe $daysLeft gün kaldı (Günde ~$neededPerDay sayfa)';
      }
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Grab Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Başlık ve Rozet
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accentColor.withValues(alpha: 0.15),
                      border: Border.all(color: accentColor.withValues(alpha: 0.4), width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(isMukabele ? '🕌' : '📖', style: const TextStyle(fontSize: 26)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isMukabele ? 'Mukabele Hatmi' : 'Şahsi Hatim',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: accentColor,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                color: accentColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '%$progressPercent',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hatim.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3. Büyük İlerleme Çubuğu
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (completedPages / 604.0).clamp(0.01, 1.0),
                  minHeight: 8,
                  backgroundColor: surfaceBg,
                  valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                ),
              ),
              const SizedBox(height: 16),

              // 4. İstatistik Kutucukları (2x2 Grid)
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Tamamlanan',
                      value: '$completedPages / 604',
                      subtext: '$remainingPages sayfa kaldı',
                      icon: Icons.auto_stories_rounded,
                      accentColor: accentColor,
                      surfaceBg: surfaceBg,
                      borderStroke: borderStroke,
                      primaryTextColor: primaryTextColor,
                      secondaryTextColor: secondaryTextColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Bulunulan Konum',
                      value: '$currentJuz. Cüz',
                      subtext: '$pageInJuz. sayfasında',
                      icon: Icons.bookmark_added_rounded,
                      accentColor: accentColor,
                      surfaceBg: surfaceBg,
                      borderStroke: borderStroke,
                      primaryTextColor: primaryTextColor,
                      secondaryTextColor: secondaryTextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Bugün Okunan',
                      value: '$todayPages sayfa',
                      subtext: todayPages > 0 ? 'Gayretiniz bereketli olsun' : 'Bugün henüz okunmadı',
                      icon: Icons.today_rounded,
                      accentColor: accentColor,
                      surfaceBg: surfaceBg,
                      borderStroke: borderStroke,
                      primaryTextColor: primaryTextColor,
                      secondaryTextColor: secondaryTextColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Son Okuma',
                      value: _formatLastRead(lastReadDate),
                      subtext: 'Başlangıç: ${hatim.createdAt.day}.${hatim.createdAt.month}.${hatim.createdAt.year}',
                      icon: Icons.history_rounded,
                      accentColor: accentColor,
                      surfaceBg: surfaceBg,
                      borderStroke: borderStroke,
                      primaryTextColor: primaryTextColor,
                      secondaryTextColor: secondaryTextColor,
                    ),
                  ),
                ],
              ),

              if (estimatedFinishText != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accentColor.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.speed_rounded, size: 16, color: accentColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          estimatedFinishText,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // 5. 30 Cüz İlerleme Haritası
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '30 Cüz İlerleme Haritası',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: primaryTextColor,
                    ),
                  ),
                  Text(
                    '${(completedPages / 20.13).floor().clamp(0, 30)} / 30 Cüz',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: surfaceBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderStroke),
                ),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                    childAspectRatio: 1.25,
                  ),
                  itemCount: 30,
                  itemBuilder: (context, index) {
                    final juzNo = index + 1;
                    final start = SurahDataProvider.getJuzStartPage(juzNo);
                    final end = (juzNo == 30) ? 605 : SurahDataProvider.getJuzStartPage(juzNo + 1) - 1;

                    final isCompleted = completedPages >= end;
                    final isCurrent = !isCompleted && completedPages >= start;

                    Color bg;
                    Color border;
                    Color textCol;

                    if (isCompleted) {
                      bg = accentColor;
                      border = accentColor;
                      textCol = Colors.white;
                    } else if (isCurrent) {
                      bg = accentColor.withValues(alpha: 0.2);
                      border = accentColor;
                      textCol = accentColor;
                    } else {
                      bg = cardBg;
                      border = borderStroke;
                      textCol = secondaryTextColor;
                    }

                    return Container(
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: border, width: isCurrent ? 1.5 : 1),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        isCompleted ? '✓ $juzNo' : '$juzNo',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isCurrent || isCompleted ? FontWeight.bold : FontWeight.w500,
                          color: textCol,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 22),

              // 6. Alt Aksiyon Butonları
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryTextColor,
                        side: BorderSide(color: borderStroke),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Kapat', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 3,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        onContinue();
                      },
                      icon: Icon(
                        isMukabele ? Icons.play_arrow_rounded : Icons.auto_stories_rounded,
                        size: 20,
                      ),
                      label: Text(
                        isMukabele ? 'Mukabele Başlat ($currentPage. Sayfa)' : 'Okumaya Devam Et ($currentPage. Sayfa)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
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

  static Widget _buildMetricTile({
    required String label,
    required String value,
    required String subtext,
    required IconData icon,
    required Color accentColor,
    required Color surfaceBg,
    required Color borderStroke,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: surfaceBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accentColor),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: secondaryTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: primaryTextColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              color: secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  String _formatLastRead(DateTime? date) {
    if (date == null) return 'Bugün';
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Bugün';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      return 'Dün';
    }
    return '${date.day}.${date.month.toString().padLeft(2, '0')}';
  }
}

/// Dinamik Sûre Detay Bottom Sheet'i
class DynamicSurahDetailBottomSheet extends StatelessWidget {
  final DynamicSurahInfo info;
  final VoidCallback onRead;
  final VoidCallback onListen;

  const DynamicSurahDetailBottomSheet({
    super.key,
    required this.info,
    required this.onRead,
    required this.onListen,
  });

  static Future<void> show({
    required BuildContext context,
    required DynamicSurahInfo info,
    required VoidCallback onRead,
    required VoidCallback onListen,
  }) {
    HapticService.selectionClick();
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DynamicSurahDetailBottomSheet(
        info: info,
        onRead: onRead,
        onListen: onListen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E2128) : Colors.white;
    final primaryTextColor = isDark ? const Color(0xFFE8DDD0) : const Color(0xFF1E2B27);
    final secondaryTextColor = isDark ? const Color(0xFFA89888) : const Color(0xFF506861);
    final surfaceBg = isDark ? const Color(0xFF272C35) : const Color(0xFFF3F7F5);
    final borderStroke = isDark ? const Color(0xFF353C48) : const Color(0xFFDEE9E5);

    const coralBg = Color(0xFFEF7C65);
    final surahItem = SurahDataProvider.getSurahById(info.surahId);
    final (startP, endP) = SurahDataProvider.getSurahDiyanetPageRange(info.surahId);
    final juzNo = surahItem?.juzNumber ?? SurahDataProvider.getJuzForPage(info.startPage);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Grab Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Başlık Row
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: coralBg.withValues(alpha: 0.18),
                      border: Border.all(color: coralBg.withValues(alpha: 0.4), width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(info.icon, style: const TextStyle(fontSize: 26)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: coralBg.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            info.subtitle,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: coralBg,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              info.title,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: primaryTextColor,
                              ),
                            ),
                            if (surahItem != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                surahItem.nameArabic,
                                style: const TextStyle(
                                  fontFamily: 'Amiri',
                                  fontSize: 17,
                                  color: coralBg,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // 3. Sûre Künyesi Kartı
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: surfaceBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderStroke),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildSpecItem(
                            title: 'Nüzûl Mekânı',
                            value: surahItem?.type ?? 'Mekkî',
                            icon: Icons.location_on_outlined,
                            textColor: primaryTextColor,
                            subColor: secondaryTextColor,
                          ),
                        ),
                        Expanded(
                          child: _buildSpecItem(
                            title: 'Ayet Sayısı',
                            value: '${surahItem?.ayetSayisi ?? 0} Ayet',
                            icon: Icons.format_list_numbered_rounded,
                            textColor: primaryTextColor,
                            subColor: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSpecItem(
                            title: 'Cüz Bilgisi',
                            value: '$juzNo. Cüz',
                            icon: Icons.menu_book_rounded,
                            textColor: primaryTextColor,
                            subColor: secondaryTextColor,
                          ),
                        ),
                        Expanded(
                          child: _buildSpecItem(
                            title: 'Sayfa Aralığı',
                            value: '$startP. - $endP. Sayfa',
                            icon: Icons.chrome_reader_mode_outlined,
                            textColor: primaryTextColor,
                            subColor: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. Hadis-i Şerif ve Fazilet Alanı
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: coralBg.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: coralBg.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text('✨', style: TextStyle(fontSize: 16)),
                        SizedBox(width: 8),
                        Text(
                          'Sûrenin Fazileti ve Hikmeti',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: coralBg,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      info.virtue,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: primaryTextColor,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // 5. Butonlar
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: coralBg,
                        side: const BorderSide(color: coralBg),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        onListen();
                      },
                      icon: const Icon(Icons.headphones_rounded, size: 18),
                      label: const Text('Dinle', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: coralBg,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 3,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        onRead();
                      },
                      icon: const Icon(Icons.auto_stories_rounded, size: 18),
                      label: const Text('Sûreyi Oku', style: TextStyle(fontWeight: FontWeight.bold)),
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

  static Widget _buildSpecItem({
    required String title,
    required String value,
    required IconData icon,
    required Color textColor,
    required Color subColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: subColor),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 10, color: subColor)),
            Text(value, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textColor)),
          ],
        ),
      ],
    );
  }
}

/// Dinamik Kur'an Okuma Rozetleri & Sure Streaks Detay Bottom Sheet'i
class SurahStreakDetailBottomSheet extends StatelessWidget {
  final String title;
  final String subtitle;
  final String icon;
  final String badgeText;
  final List<Color> bgGradient;
  final int readCount;
  final int streakDays;
  final int targetDays;
  final int dailyTarget;
  final int todayReadCount;
  final CustomQuranBadge? customBadge;
  final VoidCallback? onBadgeUpdated;
  final VoidCallback onStartReading;

  const SurahStreakDetailBottomSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.badgeText,
    required this.bgGradient,
    this.readCount = 0,
    required this.streakDays,
    this.targetDays = 40,
    this.dailyTarget = 1,
    this.todayReadCount = 0,
    this.customBadge,
    this.onBadgeUpdated,
    required this.onStartReading,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String icon,
    required String badgeText,
    required List<Color> bgGradient,
    int readCount = 0,
    required int streakDays,
    int targetDays = 40,
    int dailyTarget = 1,
    int todayReadCount = 0,
    CustomQuranBadge? customBadge,
    VoidCallback? onBadgeUpdated,
    required VoidCallback onStartReading,
  }) {
    HapticService.selectionClick();
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SurahStreakDetailBottomSheet(
        title: title,
        subtitle: subtitle,
        icon: icon,
        badgeText: badgeText,
        bgGradient: bgGradient,
        readCount: readCount,
        streakDays: streakDays,
        targetDays: targetDays,
        dailyTarget: dailyTarget,
        todayReadCount: todayReadCount,
        customBadge: customBadge,
        onBadgeUpdated: onBadgeUpdated,
        onStartReading: onStartReading,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E2128) : Colors.white;
    final primaryTextColor = isDark ? const Color(0xFFE8DDD0) : const Color(0xFF1E2B27);
    final secondaryTextColor = isDark ? const Color(0xFFA89888) : const Color(0xFF506861);
    final surfaceBg = isDark ? const Color(0xFF272C35) : const Color(0xFFF3F7F5);
    final borderStroke = isDark ? const Color(0xFF353C48) : const Color(0xFFDEE9E5);
    final accentColor = bgGradient.first;

    final displayCount = readCount > 0 ? readCount : streakDays;
    final isInfinite = targetDays <= 0;
    final progressPct = isInfinite
        ? (dailyTarget > 1 ? ((todayReadCount / dailyTarget) * 100).clamp(0, 100).toInt() : 100)
        : ((displayCount / targetDays) * 100).clamp(0, 100).toInt();
    final remainingDays = isInfinite ? 0 : (targetDays - displayCount).clamp(0, targetDays);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Grab Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Başlık Row
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: bgGradient),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(icon, style: const TextStyle(fontSize: 26)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                badgeText,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: accentColor,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (customBadge != null)
                              InkWell(
                                onTap: () {
                                  Navigator.of(context).pop();
                                  AddCustomQuranBadgeSheet.show(
                                    context,
                                    badgeToEdit: customBadge,
                                    onBadgeCreated: onBadgeUpdated,
                                  );
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: accentColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: accentColor.withValues(alpha: 0.25)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.edit_outlined, size: 12, color: accentColor),
                                      const SizedBox(width: 3),
                                      Text(
                                        'Hedefi Düzenle',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: accentColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            Text(
                              isInfinite ? '∞ Sonsuz' : '%$progressPct',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$title Virdi',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 3. İlerleme Özet Kartı
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: surfaceBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderStroke),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn('Toplam Okuma', isInfinite ? '$displayCount' : '$displayCount/$targetDays', accentColor),
                    Container(width: 1, height: 28, color: borderStroke),
                    _buildStatColumn('Günlük Seri', streakDays > 0 ? '🔥 $streakDays Gün' : '0 Gün', const Color(0xFFEF6C00)),
                    Container(width: 1, height: 28, color: borderStroke),
                    if (isInfinite || dailyTarget > 1)
                      _buildStatColumn('Bugünkü Hedef', dailyTarget > 1 ? '$todayReadCount/$dailyTarget' : 'Serbest', const Color(0xFF2E7D32))
                    else
                      _buildStatColumn('Kalan', '$remainingDays', secondaryTextColor),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 4. Görsel İlerleme Bölümü (Izgara / Kilometre Taşı)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isInfinite
                        ? 'Sonsuz Vird & Manevi Eşikler'
                        : (targetDays <= 100
                            ? '$targetDays Okuma İlerleme Tablosu'
                            : '$targetDays Okuma Kilometre Taşları'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: primaryTextColor,
                    ),
                  ),
                  Text(
                    isInfinite
                        ? '$displayCount Okuma Yapıldı'
                        : (displayCount >= targetDays
                            ? '🎉 Hedef Tamamlandı!'
                            : '$displayCount/$targetDays Okuma'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (!isInfinite && targetDays <= 100) ...[
                // Izgara tablosu (7, 14, 21, 33, 40, 70, 99, 100 vb.)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: surfaceBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderStroke),
                  ),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: targetDays <= 21 ? 7 : (targetDays <= 40 ? 8 : 10),
                      crossAxisSpacing: 5,
                      mainAxisSpacing: 5,
                      childAspectRatio: targetDays <= 40 ? 1.1 : 1.0,
                    ),
                    itemCount: targetDays,
                    itemBuilder: (context, index) {
                      final day = index + 1;
                      final isDone = day <= displayCount;
                      final isCurrent = day == displayCount + 1;

                      Color bg;
                      Color border;
                      Color textCol;

                      if (isDone) {
                        bg = accentColor;
                        border = accentColor;
                        textCol = Colors.white;
                      } else if (isCurrent) {
                        bg = accentColor.withValues(alpha: 0.18);
                        border = accentColor;
                        textCol = accentColor;
                      } else {
                        bg = cardBg;
                        border = borderStroke;
                        textCol = secondaryTextColor.withValues(alpha: 0.6);
                      }

                      return Container(
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: border, width: isCurrent ? 1.5 : 1),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          isDone ? '✓' : '$day',
                          style: TextStyle(
                            fontSize: targetDays <= 40 ? 9.5 : 8.5,
                            fontWeight: isDone || isCurrent ? FontWeight.bold : FontWeight.normal,
                            color: textCol,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ] else if (!isInfinite && targetDays > 100) ...[
                // 100+ Hedefler için Kilometre Taşı Çubuğu
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surfaceBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderStroke),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Toplam İlerleme',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryTextColor),
                          ),
                          Text(
                            '%$progressPct ($displayCount/$targetDays)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: accentColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: (displayCount / targetDays.toDouble()).clamp(0.0, 1.0),
                          minHeight: 10,
                          backgroundColor: borderStroke,
                          valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMilestonePill('Başla', 0, displayCount, accentColor, borderStroke),
                          _buildMilestonePill('%25', (targetDays * 0.25).round(), displayCount, accentColor, borderStroke),
                          _buildMilestonePill('%50', (targetDays * 0.50).round(), displayCount, accentColor, borderStroke),
                          _buildMilestonePill('%75', (targetDays * 0.75).round(), displayCount, accentColor, borderStroke),
                          _buildMilestonePill('Hedef', targetDays, displayCount, accentColor, borderStroke),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Sonsuz Hedef için Manevi Eşikler (Milestones)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surfaceBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderStroke),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manevi Fazilet Menzilleri',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: primaryTextColor),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildInfiniteMilestoneCard('40 Okuma', 'Muhafız', displayCount >= 40, accentColor, borderStroke, surfaceBg),
                          _buildInfiniteMilestoneCard('100 Okuma', 'Dost', displayCount >= 100, accentColor, borderStroke, surfaceBg),
                          _buildInfiniteMilestoneCard('313 Okuma', 'Bedir', displayCount >= 313, accentColor, borderStroke, surfaceBg),
                          _buildInfiniteMilestoneCard('1000 Okuma', 'Büyük Vird', displayCount >= 1000, accentColor, borderStroke, surfaceBg),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              if (dailyTarget > 1) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accentColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Text('🎯', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Bugünkü Hedef ($dailyTarget Okuma)',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: accentColor),
                                ),
                                Text(
                                  todayReadCount >= dailyTarget ? '✓ Tamamlandı' : '$todayReadCount/$dailyTarget Okundu',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: todayReadCount >= dailyTarget ? const Color(0xFF2E7D32) : accentColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (todayReadCount / dailyTarget.toDouble()).clamp(0.0, 1.0),
                                minHeight: 6,
                                backgroundColor: accentColor.withValues(alpha: 0.2),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  todayReadCount >= dailyTarget ? const Color(0xFF2E7D32) : accentColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // 5. Vird Fazileti & Tavsiye
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accentColor.withValues(alpha: 0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🌿', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$title Manevi Bereketi',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.4,
                              color: primaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // 6. Başlat Butonu
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 3,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  onStartReading();
                },
                icon: const Icon(Icons.auto_stories_rounded, size: 20),
                label: Text(
                  'Okumayı Başlat (${displayCount + 1}. Okuma)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildStatColumn(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: valueColor),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildMilestonePill(String label, int targetValue, int currentValue, Color accentColor, Color borderStroke) {
    final reached = currentValue >= targetValue;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
          decoration: BoxDecoration(
            color: reached ? accentColor : borderStroke,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            reached ? '✓ $label' : label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: reached ? Colors.white : Colors.grey,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$targetValue',
          style: TextStyle(fontSize: 9, color: reached ? accentColor : Colors.grey),
        ),
      ],
    );
  }

  Widget _buildInfiniteMilestoneCard(String countText, String title, bool isDone, Color accentColor, Color borderStroke, Color surfaceBg) {
    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: isDone ? accentColor.withValues(alpha: 0.15) : surfaceBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDone ? accentColor : borderStroke),
      ),
      child: Column(
        children: [
          Text(
            isDone ? '✨' : '🔒',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isDone ? accentColor : Colors.grey,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            countText,
            style: TextStyle(
              fontSize: 8.5,
              color: isDone ? accentColor.withValues(alpha: 0.8) : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
