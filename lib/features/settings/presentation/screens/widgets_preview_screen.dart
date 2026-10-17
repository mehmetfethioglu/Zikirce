import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/services/widget_sync_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/utils/hijri_calendar.dart';
import '../../../namaz_vakitleri/providers/prayer_providers.dart';
import '../../../namaz_vakitleri/presentation/widgets/analog_prayer_clock.dart';

class WidgetsPreviewScreen extends ConsumerStatefulWidget {
  const WidgetsPreviewScreen({super.key});

  @override
  ConsumerState<WidgetsPreviewScreen> createState() => _WidgetsPreviewScreenState();
}

class _WidgetsPreviewScreenState extends ConsumerState<WidgetsPreviewScreen> {
  bool _isSyncing = false;

  Future<void> _handleSync() async {
    setState(() => _isSyncing = true);
    final db = ref.read(databaseProvider);
    await WidgetSyncService.syncAll(db);
    setState(() => _isSyncing = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.isTurkish
                ? 'Tüm ana ekran widget\'ları başarıyla güncellendi!'
                : 'All home screen widgets updated successfully!',
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final prayerAsync = ref.watch(prayerTimingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        title: Text(
          l10n.isTurkish ? 'Ana Ekran Widget\'ları' : 'Home Screen Widgets',
          style: TextStyle(color: colors.primaryText, fontWeight: FontWeight.bold),
        ),
        backgroundColor: colors.pageBackground,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.primaryText),
        actions: [
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD4A574)),
                  )
                : const Icon(Icons.sync_rounded),
            tooltip: l10n.isTurkish ? 'Widget\'ları Senkronize Et' : 'Sync Widgets',
            onPressed: _isSyncing ? null : _handleSync,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Info banner
          _buildInfoBanner(colors, l10n),
          const SizedBox(height: 16),

          // 1. Namaz Vakitleri (4x2 Büyük Tablo)
          _buildWidgetCard(
            title: l10n.isTurkish ? '1. Namaz Vakitleri (Büyük Tablo)' : '1. Prayer Times (Large Table)',
            sizeLabel: '4x2 / 4x3',
            description: l10n.isTurkish
                ? 'Tüm namaz vakitlerini, aktif vaktin geri sayımını ve Hicri tarihi gösterir.'
                : 'Shows all prayer times, active prayer countdown, and Hijri date.',
            colors: colors,
            child: _buildPrayerTimesTableMock(colors, prayerAsync.valueOrNull),
          ),
          const SizedBox(height: 16),

          // 2. Namaz Vakitleri Mini (4x1 Kompakt Şerit)
          _buildWidgetCard(
            title: l10n.isTurkish ? '2. Namaz Vakitleri (Mini Şerit)' : '2. Prayer Times (Mini Banner)',
            sizeLabel: '4x1 / 2x1',
            description: l10n.isTurkish
                ? 'Sonraki vakti ve kalan canlı süreyi tek satırda gösterir.'
                : 'Displays the next prayer and live countdown in a compact bar.',
            colors: colors,
            child: _buildPrayerTimesMiniMock(colors, prayerAsync.valueOrNull),
          ),
          const SizedBox(height: 16),

          // 3. Vakit Sayacı (2x2 Dairesel İlerleme)
          _buildWidgetCard(
            title: l10n.isTurkish ? '3. Vakit Sayacı (Dairesel Halka)' : '3. Prayer Countdown (Circular Ring)',
            sizeLabel: '2x2',
            description: l10n.isTurkish
                ? 'Fıkhi renk skalalı dinamik ilerleme halkası ve 60 çentikli sayaç.'
                : 'Concentric circular progress ring with fiqh colors and countdown.',
            colors: colors,
            child: _buildPrayerCountdownMock(colors, isDark),
          ),
          const SizedBox(height: 16),

          // 4. Dijital Saat Vakitleri (2x2 / 3x2)
          _buildWidgetCard(
            title: l10n.isTurkish ? '4. Dijital Saat Vakitleri' : '4. Digital Clock & Prayers',
            sizeLabel: '2x2 / 3x2',
            description: l10n.isTurkish
                ? 'Büyük dijital saat, yönelme vakti ve anlık geri sayım.'
                : 'Large digital TextClock, target prayer name and countdown.',
            colors: colors,
            child: _buildDigitalClockMock(colors, isDark),
          ),
          const SizedBox(height: 16),

          // 5. Namaz Vakti Saati (2x2 Selçuklu Yıldızı & Tesbih Analog Kadran)
          _buildWidgetCard(
            title: l10n.isTurkish ? '5. Selçuklu Yıldızı & Tesbih Analog Saat' : '5. Seljuk Star & Tasbih Analog Clock',
            sizeLabel: '2x2 / 3x3',
            description: l10n.isTurkish
                ? 'Zikirce logosundaki 8 köşeli yuvarlatılmış Selçuklu yıldızı ve tesbih çerçevesi, 12-3-6-9 rakamları ve en altta zarif canlı geri sayım sayacı.'
                : 'Zikirce 8-pointed rounded Seljuk star & tasbih frame, 12-3-6-9 numerals, and an elegant live countdown timer at the bottom.',
            colors: colors,
            child: _buildAnalogClockMock(colors, isDark),
          ),

          const SizedBox(height: 16),

          // 6. Hicri Takvim (2x2)
          _buildWidgetCard(
            title: l10n.isTurkish ? '6. Hicri Takvim' : '6. Hijri Calendar',
            sizeLabel: '2x2 / 3x2',
            description: l10n.isTurkish
                ? 'Günün Hicri günü, ayı, yılı ve Miladi takvim eşleştirmesi.'
                : 'Large Hijri day number, Hijri month/year and Gregorian date.',
            colors: colors,
            child: _buildHijriCalendarMock(colors, isDark),
          ),
          const SizedBox(height: 16),

          // 7. Kaza & Namaz Takibi (4x1 / 4x2)
          _buildWidgetCard(
            title: l10n.isTurkish ? '7. Namaz & Kaza Takibi (Hızlı Azaltma)' : '7. Kaza Prayer Tracker (Interactive)',
            sizeLabel: '4x1 / 4x2',
            description: l10n.isTurkish
                ? 'Kaza borçlarınızı takip edin ve ana ekrandan tek tıkla kaza düşün.'
                : 'Track kaza debts and decrement directly from your home screen.',
            colors: colors,
            child: _buildKazaWidgetMock(colors, isDark),
          ),
          const SizedBox(height: 16),

          // 8. Manevi Kalp Sağlığı (2x2)
          _buildWidgetCard(
            title: l10n.isTurkish ? '8. Manevi Kalp Sağlığı' : '8. Spiritual Heart Health',
            sizeLabel: '2x2 / 3x2',
            description: l10n.isTurkish
                ? 'Bugünkü toplam zikir adedi ve haftalık zikir hareket eğrisi.'
                : 'Today\'s total dhikrs and weekly Bezier trend curve.',
            colors: colors,
            child: _buildKalpSagligiMock(colors, isDark),
          ),
          const SizedBox(height: 16),

          // 9. Günlük Seri (2x2)
          _buildWidgetCard(
            title: l10n.isTurkish ? '9. Günlük Seri & Zikirmatik' : '9. Daily Streak & Dhikr',
            sizeLabel: '2x2 / 3x2',
            description: l10n.isTurkish
                ? 'Günlük ibadet seriniz, kutlama konfetileri ve 7 günlük durum.'
                : 'Daily streak count, celebration confetti, and 7-day capsule row.',
            colors: colors,
            child: _buildStreakMock(colors, isDark),
          ),
          const SizedBox(height: 24),

          // How to add widgets guide
          _buildHowToAddGuide(colors, l10n),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildInfoBanner(AppThemeColors colors, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.widgets_rounded, color: colors.accent, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.isTurkish ? '9 Zengin Ana Ekran Widget\'ı' : '9 Rich Home Screen Widgets',
                  style: TextStyle(
                    color: colors.primaryText,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.isTurkish
                      ? 'Telefonunuzun ana ekranına ekleyerek vakitleri, zikirlerinizi ve kazalarınızı canlı takip edin.'
                      : 'Add them to your device home screen for real-time prayer times, dhikrs, and kaza tracking.',
                  style: TextStyle(color: colors.secondaryTextAlt, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWidgetCard({
    required String title,
    required String sizeLabel,
    required String description,
    required AppThemeColors colors,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.borderStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: colors.primaryText,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  sizeLabel,
                  style: TextStyle(
                    color: colors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(color: colors.secondaryTextAlt, fontSize: 11),
          ),
          const SizedBox(height: 14),
          Center(child: child),
        ],
      ),
    );
  }

  Widget _buildPrayerTimesTableMock(AppThemeColors colors, dynamic timings) {
    final now = DateTime.now();
    final hijri = HijriDate.fromGregorian(now);
    final hijriStr = '${hijri.day} ${hijri.monthName} ${hijri.year}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF161D30), Color(0xFF0A0B12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('İstanbul', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              Text(hijriStr, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0x20F59E0B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFBBF24)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('AKŞAMA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                Text('17:44  •  01:23:45', style: TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildPrayerPill('İmsak', '04:12'),
              _buildPrayerPill('Güneş', '05:48'),
              _buildPrayerPill('Öğle', '13:08'),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _buildPrayerPill('İkindi', '16:54'),
              _buildPrayerPill('Akşam', '20:18', isActive: true),
              _buildPrayerPill('Yatsı', '21:46'),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildPrayerPill(String name, String time, {bool isActive = false}) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0x20F59E0B) : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: isActive ? Border.all(color: const Color(0xFFFBBF24), width: 1) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9)),
            Text(time, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Widget _buildPrayerTimesMiniMock(AppThemeColors colors, dynamic timings) {
    final now = DateTime.now();
    final hijri = HijriDate.fromGregorian(now);
    final hijriStr = '${hijri.day} ${hijri.monthName} ${hijri.year}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF161D30), Color(0xFF0A0B12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('İstanbul', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              Text(hijriStr, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9)),
            ],
          ),
          const Column(
            children: [
              Text('Sonraki Namaz', style: TextStyle(color: Color(0xFF64748B), fontSize: 9)),
              Text('Akşam', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('17:44', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 14)),
              Text('01:23:45', style: TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerCountdownMock(AppThemeColors colors, bool isDark) {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A120B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.borderStroke),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: CircularProgressIndicator(
              value: 0.65,
              strokeWidth: 8,
              backgroundColor: isDark ? const Color(0xFF2A2520) : const Color(0xFFF2E6D9),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('AKŞAMA', style: TextStyle(color: Color(0xFFB45309), fontSize: 10, fontWeight: FontWeight.bold)),
              Text('01:23:45', style: TextStyle(color: colors.primaryText, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDigitalClockMock(AppThemeColors colors, bool isDark) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : const Color(0xFFFFFDF9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.borderStroke),
      ),
      child: Column(
        children: [
          const Text('AKŞAMA', style: TextStyle(color: Color(0xFFB45309), fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          const Text('01:23:45', style: TextStyle(color: Color(0xFFB45309), fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            '16:20',
            style: TextStyle(
              color: colors.primaryText,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalogClockMock(AppThemeColors colors, bool isDark) {
    return Container(
      width: 156,
      height: 156,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AnalogPrayerClock(
        size: 156,
        isDark: isDark,
      ),
    );
  }


  Widget _buildHijriCalendarMock(AppThemeColors colors, bool isDark) {
    final now = DateTime.now();
    final hijri = HijriDate.fromGregorian(now);
    const dayNames = ['PAZARTESİ', 'SALI', 'ÇARŞAMBA', 'PERŞEMBE', 'CUMA', 'CUMARTESİ', 'PAZAR'];
    final dayName = dayNames[(now.weekday - 1) % 7];
    const monthsTr = ['OCAK', 'ŞUBAT', 'MART', 'NİSAN', 'MAYIS', 'HAZİRAN', 'TEMMUZ', 'AĞUSTOS', 'EYLÜL', 'EKİM', 'KASIM', 'ARALIK'];
    final gregDate = '${now.day} ${monthsTr[now.month - 1]} ${now.year}';

    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : const Color(0xFFFFFDF9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.borderStroke),
      ),
      child: Column(
        children: [
          Text(dayName, style: const TextStyle(color: Color(0xFFB45309), fontSize: 10, fontWeight: FontWeight.bold)),
          Text('${hijri.day}', style: TextStyle(color: colors.primaryText, fontSize: 40, fontWeight: FontWeight.bold)),
          Text('${hijri.monthName.toUpperCase()} ${hijri.year}', style: const TextStyle(color: Color(0xFFB45309), fontSize: 10, fontWeight: FontWeight.bold)),
          const Divider(height: 12),
          Text(gregDate, style: TextStyle(color: colors.secondaryTextAlt, fontSize: 8, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildKazaWidgetMock(AppThemeColors colors, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : const Color(0xFFF7F1E5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderStroke),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('KAZA BORÇLARIM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              Text('Toplam: 0', style: TextStyle(color: Color(0xFFD93025), fontWeight: FontWeight.bold, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildKazaPill('Sabah', 0, colors, isDark),
              _buildKazaPill('Öğle', 0, colors, isDark),
              _buildKazaPill('İkindi', 0, colors, isDark),
              _buildKazaPill('Akşam', 0, colors, isDark),
              _buildKazaPill('Yatsı', 0, colors, isDark),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildKazaPill(String name, int count, AppThemeColors colors, bool isDark) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF18181B) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.borderStroke),
        ),
        child: Column(
          children: [
            Text(name, style: TextStyle(color: colors.secondaryTextAlt, fontSize: 8, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text('$count', style: TextStyle(color: colors.primaryText, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildKalpSagligiMock(AppThemeColors colors, bool isDark) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.borderStroke),
      ),
      child: Column(
        children: [
          Text('34.797', style: TextStyle(color: colors.primaryText, fontSize: 24, fontWeight: FontWeight.bold)),
          Text('Kalp Sağlığı', style: TextStyle(color: colors.primaryText, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Container(
            height: 35,
            decoration: BoxDecoration(
              color: const Color(0xFFE64A19).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text('📈 Haftalık Trend', style: TextStyle(color: Color(0xFFE64A19), fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakMock(AppThemeColors colors, bool isDark) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.borderStroke),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.accent.withValues(alpha: 0.15),
              border: Border.all(color: colors.accent),
            ),
            child: Center(
              child: Text('26', style: TextStyle(color: colors.primaryText, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 6),
          Text('Harika Gidiyorsun!', style: TextStyle(color: colors.primaryText, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(7, (i) => Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < 5 ? const Color(0xFF10B981) : colors.borderStroke,
              ),
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildHowToAddGuide(AppThemeColors colors, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.touch_app_rounded, color: Color(0xFF10B981), size: 20),
              const SizedBox(width: 8),
              Text(
                l10n.isTurkish ? 'Ana Ekrana Nasıl Eklenir?' : 'How to Add to Home Screen?',
                style: TextStyle(color: colors.primaryText, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildGuideStep('1', l10n.isTurkish ? 'Telefonunuzun ana ekranında boş bir alana basılı tutun.' : 'Long-press on an empty area of your device home screen.', colors),
          _buildGuideStep('2', l10n.isTurkish ? 'Açılan menüden "Widget\'lar / Araçlar" seçeneğine dokunun.' : 'Tap on "Widgets" from the popup menu.', colors),
          _buildGuideStep('3', l10n.isTurkish ? 'Listeden "Zikirce" uygulamasını bulun.' : 'Find "Zikirce" in the widget list.', colors),
          _buildGuideStep('4', l10n.isTurkish ? 'İstediğiniz widget\'ı seçip ana ekranınıza sürükleyip bırakın.' : 'Select any of the 9 widgets and drag it to your screen.', colors),
        ],
      ),
    );
  }

  Widget _buildGuideStep(String step, String text, AppThemeColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step,
                style: TextStyle(color: colors.accent, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: colors.secondaryTextAlt, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
