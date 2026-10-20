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
import 'zikir_share_card_widget.dart';

class ZikirSharePreviewModal extends ConsumerStatefulWidget {
  final String zikirName;
  final String? arabicText;
  final String? virtue;
  final String category;
  final int currentCount;
  final int targetCount;
  final int totalCount;
  final String arabicFontFamily;
  final ZikirShareCardTheme? initialTheme;

  const ZikirSharePreviewModal({
    super.key,
    required this.zikirName,
    this.arabicText,
    this.virtue,
    required this.category,
    required this.currentCount,
    required this.targetCount,
    required this.totalCount,
    this.arabicFontFamily = 'mushaf',
    this.initialTheme,
  });

  static Future<void> show({
    required BuildContext context,
    required String zikirName,
    String? arabicText,
    String? virtue,
    String category = 'Günlük Zikir',
    int currentCount = 0,
    int targetCount = 33,
    int totalCount = 0,
    String arabicFontFamily = 'mushaf',
    ZikirShareCardTheme? initialTheme,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ZikirSharePreviewModal(
        zikirName: zikirName,
        arabicText: arabicText,
        virtue: virtue,
        category: category,
        currentCount: currentCount,
        targetCount: targetCount,
        totalCount: totalCount,
        arabicFontFamily: arabicFontFamily,
        initialTheme: initialTheme,
      ),
    );
  }

  @override
  ConsumerState<ZikirSharePreviewModal> createState() => _ZikirSharePreviewModalState();
}

class _ZikirSharePreviewModalState extends ConsumerState<ZikirSharePreviewModal> {
  final GlobalKey _cardRepaintKey = GlobalKey();

  ZikirShareCardFormat _selectedFormat = ZikirShareCardFormat.story9x16;
  late ZikirShareCardTheme _selectedTheme;
  bool _showCounterStats = true;
  bool _isGeneratingImage = false;

  @override
  void initState() {
    super.initState();
    _selectedTheme = widget.initialTheme ??
        ZikirShareThemeData.themeForGoalOrTask(category: widget.category);
  }

  Future<void> _shareAsImage() async {
    if (_isGeneratingImage) return;

    final l10n = context.l10n;
    setState(() => _isGeneratingImage = true);
    HapticFeedback.mediumImpact();

    try {
      // Small delay to ensure render tree is fully painted
      await Future.delayed(const Duration(milliseconds: 60));

      final boundary = _cardRepaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('RenderRepaintBoundary bulunamadı.');
      }

      // 3.0 pixel ratio for high-density sharp image (e.g. 1080x1920)
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Görsel baytları oluşturulamadı.');
      }

      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final fileName = 'zikirce_kart_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pngBytes);

      final caption = l10n.isTurkish
          ? '📿 ${widget.zikirName} — Zikirce İslâmî Yaşam ve Zikir Asistanı'
          : '📿 ${widget.zikirName} — Zikirce Islamic Life & Dhikr Assistant';

      if (mounted) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: caption,
          subject: '${widget.zikirName} - Zikirce',
        );
      }
    } catch (e) {
      debugPrint('[ZikirSharePreviewModal] Görsel paylaşım hatası: $e');
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
    final arabicPart = (widget.arabicText != null && widget.arabicText!.isNotEmpty)
        ? '\n${widget.arabicText!}\n'
        : '';
    final virtuePart = (widget.virtue != null && widget.virtue!.isNotEmpty)
        ? '\n💡 ${l10n.isTurkish ? "Fazileti" : "Virtue"}: ${widget.virtue}\n'
        : '';

    final shareText = l10n.isTurkish
        ? '📿 ${widget.zikirName}$arabicPart\n🎯 Hedef: ${widget.targetCount}\n✅ Çekilen: ${widget.currentCount}\n📊 Toplam: ${widget.totalCount}$virtuePart\n— Zikirce İslâmî Yaşam ve Zikir Asistanı'
        : '📿 ${widget.zikirName}$arabicPart\n🎯 Target: ${widget.targetCount}\n✅ Recited: ${widget.currentCount}\n📊 Total: ${widget.totalCount}$virtuePart\n— Zikirce Islamic Life & Dhikr Assistant';

    Share.share(
      shareText,
      subject: '${widget.zikirName} - Zikirce',
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
                      const Icon(Icons.share_rounded, color: AppColors.gold500, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Zikir Kartı Paylaş',
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

              // Controls Bar: Format Selector & Stats Switch
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A232E) : const Color(0xFFF2F4F7),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Format Segmented Buttons
                    Row(
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
                        const SizedBox(width: 6),
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

                    // Stats Toggle
                    InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _showCounterStats = !_showCounterStats);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              _showCounterStats ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                              color: _showCounterStats ? AppColors.gold500 : (isDark ? Colors.white38 : Colors.black38),
                              size: 20,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Sayaç',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Interactive Live Card Preview (Framed inside RepaintBoundary)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: maxPreviewHeight,
                ),
                child: RepaintBoundary(
                  key: _cardRepaintKey,
                  child: ZikirShareCardWidget(
                    zikirName: widget.zikirName,
                    arabicText: widget.arabicText,
                    virtue: widget.virtue,
                    category: widget.category,
                    currentCount: widget.currentCount,
                    targetCount: widget.targetCount,
                    totalCount: widget.totalCount,
                    format: _selectedFormat,
                    theme: _selectedTheme,
                    showCounterStats: _showCounterStats,
                    arabicFontFamily: widget.arabicFontFamily,
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
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: ZikirShareCardTheme.values.map((themeOption) {
                        final themeData = ZikirShareThemeData.fromEnum(themeOption);
                        final isSelected = _selectedTheme == themeOption;

                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedTheme = themeOption);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSelected) ...[
                                  Icon(Icons.check_circle_rounded, size: 14, color: themeData.accentColor),
                                  const SizedBox(width: 5),
                                ],
                                Text(
                                  themeData.nameTr,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
