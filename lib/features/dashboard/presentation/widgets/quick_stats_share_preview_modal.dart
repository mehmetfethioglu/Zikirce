import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import 'package:zikirce/features/zikir/presentation/widgets/zikir_share_card_widget.dart';
import 'quick_stats_share_card_widget.dart';

class QuickStatsSharePreviewModal extends ConsumerStatefulWidget {
  final String todayZikir;
  final String thisWeekZikir;
  final String dailyAvgZikir;
  final String totalZikir;
  final String quranPages;
  final String rankName;
  final String rankBadge;

  const QuickStatsSharePreviewModal({
    super.key,
    required this.todayZikir,
    required this.thisWeekZikir,
    required this.dailyAvgZikir,
    required this.totalZikir,
    this.quranPages = '0',
    this.rankName = 'Mübtedi',
    this.rankBadge = '🌱',
  });

  static Future<void> show({
    required BuildContext context,
    required String todayZikir,
    required String thisWeekZikir,
    required String dailyAvgZikir,
    required String totalZikir,
    String quranPages = '0',
    String rankName = 'Mübtedi',
    String rankBadge = '🌱',
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuickStatsSharePreviewModal(
        todayZikir: todayZikir,
        thisWeekZikir: thisWeekZikir,
        dailyAvgZikir: dailyAvgZikir,
        totalZikir: totalZikir,
        quranPages: quranPages,
        rankName: rankName,
        rankBadge: rankBadge,
      ),
    );
  }

  @override
  ConsumerState<QuickStatsSharePreviewModal> createState() => _QuickStatsSharePreviewModalState();
}

class _QuickStatsSharePreviewModalState extends ConsumerState<QuickStatsSharePreviewModal> {
  final GlobalKey _cardRepaintKey = GlobalKey();

  ZikirShareCardFormat _selectedFormat = ZikirShareCardFormat.story9x16;
  ZikirShareCardTheme _selectedTheme = ZikirShareCardTheme.emeraldSufi;
  bool _isGeneratingImage = false;

  Future<void> _shareAsImage() async {
    if (_isGeneratingImage) return;

    final l10n = context.l10n;
    setState(() => _isGeneratingImage = true);
    HapticFeedback.mediumImpact();

    try {
      await Future.delayed(const Duration(milliseconds: 60));

      final boundary = _cardRepaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('RenderRepaintBoundary bulunamadı.');
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Görsel baytları oluşturulamadı.');
      }

      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final fileName = 'zikirce_istatistik_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pngBytes);

      final caption = l10n.isTurkish
          ? '📊 İbadet & Zikir Özeti • Zikirce İslâmî Yaşam ve Zikir Asistanı'
          : '📊 Spiritual Worship & Dhikr Summary • Zikirce Islamic Assistant';

      if (mounted) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: caption,
          subject: 'Zikirce İbadet Özeti',
        );
      }
    } catch (e) {
      debugPrint('[QuickStatsSharePreviewModal] Görsel paylaşım hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Görsel oluşturulurken bir hata oluştu: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingImage = false);
      }
    }
  }

  void _shareAsText() {
    HapticFeedback.lightImpact();
    final l10n = context.l10n;
    final shareText = l10n.isTurkish
        ? '📊 Zikirce İbadet & Zikir Karnem:\n\n'
            '🟢 Bugün Zikir: ${widget.todayZikir}\n'
            '🔵 Bu Hafta: ${widget.thisWeekZikir}\n'
            '🟡 Günlük Ortalama: ${widget.dailyAvgZikir}\n'
            '🟣 Toplam Zikir: ${widget.totalZikir}\n'
            '📖 Kur\'an Okuma: ${widget.quranPages} Sayfa\n'
            '🌱 Manevi Makam: ${widget.rankBadge} ${widget.rankName}\n\n'
            '“Beni anın ki Ben de sizi anayım.” (Bakara, 152)\n'
            '— Zikirce İslâmî Yaşam ve Zikir Asistanı'
        : '📊 My Zikirce Spiritual Summary:\n\n'
            '🟢 Today: ${widget.todayZikir}\n'
            '🔵 This Week: ${widget.thisWeekZikir}\n'
            '🟡 Daily Average: ${widget.dailyAvgZikir}\n'
            '🟣 Total Dhikr: ${widget.totalZikir}\n'
            '📖 Quran Read: ${widget.quranPages} Pages\n'
            '🌱 Spiritual Rank: ${widget.rankBadge} ${widget.rankName}\n\n'
            '— Zikirce Islamic Life & Dhikr Assistant';

    Share.share(
      shareText,
      subject: 'Zikirce İbadet Özeti',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxPreviewHeight = MediaQuery.of(context).size.height * 0.44;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131920) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Pull Handle
              Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 14),

              // Title Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.insights_rounded, color: AppColors.gold500, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'İbadet Karnesi Paylaş',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: isDark ? Colors.white54 : Colors.black54,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Controls Bar: Format Segmented Control
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A232E) : const Color(0xFFF2F4F7),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildFormatChip(
                      title: 'Hikâye (9:16)',
                      icon: Icons.stay_current_portrait_rounded,
                      isSelected: _selectedFormat == ZikirShareCardFormat.story9x16,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedFormat = ZikirShareCardFormat.story9x16);
                      },
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildFormatChip(
                      title: 'Kare (1:1)',
                      icon: Icons.crop_square_rounded,
                      isSelected: _selectedFormat == ZikirShareCardFormat.square1x1,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedFormat = ZikirShareCardFormat.square1x1);
                      },
                      isDark: isDark,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Interactive Live Card Preview
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: maxPreviewHeight,
                ),
                child: RepaintBoundary(
                  key: _cardRepaintKey,
                  child: QuickStatsShareCardWidget(
                    todayZikir: widget.todayZikir,
                    thisWeekZikir: widget.thisWeekZikir,
                    dailyAvgZikir: widget.dailyAvgZikir,
                    totalZikir: widget.totalZikir,
                    quranPages: widget.quranPages,
                    rankName: widget.rankName,
                    rankBadge: widget.rankBadge,
                    format: _selectedFormat,
                    theme: _selectedTheme,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Theme Palette Row
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'TEMA SEÇİMİ',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white54 : Colors.black54,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  Row(
                    children: ZikirShareCardTheme.values.map((themeOption) {
                      final themeData = ZikirShareThemeData.fromEnum(themeOption);
                      final isSelected = _selectedTheme == themeOption;

                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedTheme = themeOption);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  themeData.gradientColors.first,
                                  themeData.gradientColors.last,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? themeData.accentColor : Colors.white12,
                                width: isSelected ? 2.5 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: themeData.accentColor.withValues(alpha: 0.35),
                                        blurRadius: 10,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  themeData.nameTr.split(' ').first,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // Action Buttons
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold500,
                    foregroundColor: Colors.black,
                    elevation: 4,
                    shadowColor: AppColors.gold500.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _isGeneratingImage ? null : _shareAsImage,
                  child: _isGeneratingImage
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.black,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.photo_library_rounded, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Görsel Olarak Paylaş',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 8),

              // Text Share Fallback Button
              TextButton.icon(
                onPressed: _shareAsText,
                icon: Icon(
                  Icons.text_fields_rounded,
                  size: 16,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
                label: Text(
                  'Düz Metin Olarak Paylaş',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormatChip({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF2B3848) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.gold500.withValues(alpha: 0.6) : Colors.transparent,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? AppColors.gold500 : (isDark ? Colors.white54 : Colors.black54),
            ),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? (isDark ? Colors.white : Colors.black)
                    : (isDark ? Colors.white60 : Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
