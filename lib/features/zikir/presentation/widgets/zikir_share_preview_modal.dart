import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/services/islamic_special_days_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/share_utils.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../domain/share_card_data_helper.dart';
import 'zikir_share_card_widget.dart';

class ZikirSharePreviewModal extends ConsumerStatefulWidget {
  final String zikirName;
  final String? arabicText;
  final String? virtue;
  final String? customSource;
  final String category;
  final int currentCount;
  final int targetCount;
  final int totalCount;
  final String arabicFontFamily;
  final ZikirShareCardTheme? initialTheme;
  final bool initialShowCounterStats;

  const ZikirSharePreviewModal({
    super.key,
    required this.zikirName,
    this.arabicText,
    this.virtue,
    this.customSource,
    required this.category,
    required this.currentCount,
    required this.targetCount,
    required this.totalCount,
    this.arabicFontFamily = 'AmasyaAbay',
    this.initialTheme,
    this.initialShowCounterStats = true,
  });

  static Future<void> show({
    required BuildContext context,
    required String zikirName,
    String? arabicText,
    String? virtue,
    String? customSource,
    String category = 'Günlük Zikir',
    int currentCount = 0,
    int targetCount = 33,
    int totalCount = 0,
    String arabicFontFamily = 'AmasyaAbay',
    ZikirShareCardTheme? initialTheme,
    bool initialShowCounterStats = true,
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
        customSource: customSource,
        category: category,
        currentCount: currentCount,
        targetCount: targetCount,
        totalCount: totalCount,
        arabicFontFamily: arabicFontFamily,
        initialTheme: initialTheme,
        initialShowCounterStats: initialShowCounterStats,
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
  ZikirShareTypographyStyle _selectedTypography = ZikirShareTypographyStyle.modernOutfit;
  ZikirSharePatternStyle _selectedPattern = ZikirSharePatternStyle.mihrapSufi;

  late String _activeZikirName;
  late String _activeCategory;
  String? _activeArabicText;
  String? _activeVirtue;
  String? _activeSource;
  int _quoteIndex = 0;

  late bool _showCounterStats;
  bool _showArabicText = true;
  String? _selectedGreeting;
  int _selectedNoteIndex = 0;
  bool _isGeneratingImage = false;

  @override
  void initState() {
    super.initState();
    _activeZikirName = widget.zikirName;
    _activeCategory = widget.category;
    _activeArabicText = widget.arabicText;
    _activeVirtue = widget.virtue;
    _activeSource = widget.customSource;
    _showCounterStats = widget.initialShowCounterStats;
    _selectedTheme = widget.initialTheme ??
        ZikirShareThemeData.themeForGoalOrTask(
          goalType: widget.zikirName,
          category: widget.category,
        );
    final autoDay = IslamicSpecialDaysService.detectSpecialDay();
    _selectedGreeting = autoDay?.greetingTr;
  }

  void _selectGoalPreset(ShareGoalPreset preset, bool isTurkish) {
    HapticFeedback.selectionClick();
    setState(() {
      _activeZikirName = isTurkish ? preset.badgeTitleTr : preset.badgeTitleEn;
      _activeCategory = isTurkish ? preset.labelTr : preset.labelEn;
      _activeArabicText = null;
      _activeVirtue = null;
      _activeSource = null;
      _quoteIndex = 0;
      _selectedTheme = ZikirShareThemeData.themeForGoalOrTask(
        goalType: preset.id,
        category: preset.topic,
      );
    });
  }

  void _cycleNextQuote() {
    HapticFeedback.lightImpact();
    final topicQuotes = ShareCardDataHelper.getQuotesForTopic('$_activeZikirName $_activeCategory');
    setState(() {
      _activeVirtue = null;
      _activeArabicText = null;
      _activeSource = null;
      _quoteIndex = (_quoteIndex + 1) % topicQuotes.length;
    });
  }

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

      final ui.Image image = await boundary.toImage(pixelRatio: 4.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Görsel baytları oluşturulamadı.');
      }

      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final fileName = 'zikirce_kart_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pngBytes);

      final resolvedQuote = ShareCardDataHelper.resolveQuote(
        zikirName: _activeZikirName,
        category: _activeCategory,
        rawVirtue: (_quoteIndex == 0) ? _activeVirtue : null,
        customSource: (_quoteIndex == 0) ? _activeSource : null,
        customArabic: (_quoteIndex == 0) ? _activeArabicText : null,
        quoteIndex: _quoteIndex,
      );

      final greetingPart = (_selectedGreeting != null && _selectedGreeting!.isNotEmpty)
          ? '✨ ${_selectedGreeting!}\n'
          : '';

      final caption = l10n.isTurkish
          ? '$greetingPart“${resolvedQuote.text}” (${resolvedQuote.source})\n— Zikirce İslâmî Yaşam ve Zikir Asistanı'
          : '$greetingPart“${resolvedQuote.text}” (${resolvedQuote.source})\n— Zikirce Islamic Life & Dhikr Assistant';

      if (mounted) {
        await ShareUtils.shareXFiles(
          [XFile(file.path)],
          text: caption,
          subject: '$_activeZikirName - Zikirce',
          context: context,
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

  Future<void> _shareAsText() async {
    HapticFeedback.lightImpact();
    final l10n = context.l10n;
    final resolvedQuote = ShareCardDataHelper.resolveQuote(
      zikirName: _activeZikirName,
      category: _activeCategory,
      rawVirtue: (_quoteIndex == 0) ? _activeVirtue : null,
      customSource: (_quoteIndex == 0) ? _activeSource : null,
      customArabic: (_quoteIndex == 0) ? _activeArabicText : null,
      quoteIndex: _quoteIndex,
    );

    final greetingPart = (_selectedGreeting != null && _selectedGreeting!.isNotEmpty)
        ? '✨ ${_selectedGreeting!}\n\n'
        : '';
    final arabicPart = (resolvedQuote.arabic != null && resolvedQuote.arabic!.isNotEmpty)
        ? '${resolvedQuote.arabic!}\n\n'
        : '';

    final shareText = l10n.isTurkish
        ? '$greetingPart$arabicPart“${resolvedQuote.text}”\n📖 (${resolvedQuote.source})\n\n— Zikirce İslâmî Yaşam ve Zikir Asistanı'
        : '$greetingPart$arabicPart“${resolvedQuote.text}”\n📖 (${resolvedQuote.source})\n\n— Zikirce Islamic Life & Dhikr Assistant';

    try {
      await ShareUtils.shareText(
        shareText,
        subject: '$_activeZikirName - Zikirce',
        context: context,
      );
    } catch (e) {
      debugPrint('[ZikirSharePreviewModal] Metin paylaşım hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Paylaşım başlatılırken bir hata oluştu: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTurkish = context.l10n.isTurkish;
    final maxPreviewHeight = MediaQuery.of(context).size.height * 0.40;

    final activePreset = ShareCardDataHelper.resolvePreset(
      zikirName: _activeZikirName,
      category: _activeCategory,
    );
    final isEzberGoalEnabled = ref.watch(
      userSettingsProvider.select((s) => s.isHafizlikRepeatGoalEnabled),
    );
    final visibleGoalPresets = ShareCardDataHelper.goalPresets
        .where((p) => p.id != 'ezber' || isEzberGoalEnabled || activePreset.id == 'ezber')
        .toList();
    final topicQuotes = ShareCardDataHelper.getQuotesForTopic('$_activeZikirName $_activeCategory');
    final activeNoteList = isTurkish
        ? ShareCardDataHelper.spiritualNotesTr
        : ShareCardDataHelper.spiritualNotesEn;
    final activeSpiritualNote = activeNoteList[_selectedNoteIndex.clamp(0, activeNoteList.length - 1)];

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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
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
              const SizedBox(height: 10),

              // Title Row + Quote Cycler Button
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Quote Switcher Pill (YouVersion / Ayah Style)
                      InkWell(
                        onTap: _cycleNextQuote,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.gold500.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.gold500.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.autorenew_rounded, size: 14, color: AppColors.gold500),
                              const SizedBox(width: 4),
                              Text(
                                'Ayet/Hadis (${(_quoteIndex % topicQuotes.length) + 1}/${topicQuotes.length})',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AppColors.gold400 : const Color(0xFF92400E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        color: isDark ? Colors.white54 : Colors.black54,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 1. GOAL / TOPIC PRESET BAR (Her Hedef İçin Özel Konsept Seçici)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: visibleGoalPresets.map((preset) {
                    final isSelected = activePreset.id == preset.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => _selectGoalPreset(preset, isTurkish),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.gold500.withValues(alpha: 0.22)
                                : (isDark ? const Color(0xFF1A232E) : const Color(0xFFF2F4F7)),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.gold500
                                  : (isDark ? Colors.white12 : Colors.black12),
                              width: isSelected ? 1.4 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(preset.emoji, style: const TextStyle(fontSize: 12)),
                              const SizedBox(width: 5),
                              Text(
                                isTurkish ? preset.labelTr : preset.labelEn,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected
                                      ? (isDark ? AppColors.gold400 : const Color(0xFF92400E))
                                      : (isDark ? Colors.white70 : Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),

              // 2. Controls Bar: Format Selector, Arabic Toggle & Stats Switch
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A232E) : const Color(0xFFF2F4F7),
                  borderRadius: BorderRadius.circular(16),
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
                        const SizedBox(width: 4),
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

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Arabic Toggle
                        InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _showArabicText = !_showArabicText);
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            child: Row(
                              children: [
                                Icon(
                                  _showArabicText ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                  color: _showArabicText ? AppColors.gold500 : (isDark ? Colors.white38 : Colors.black38),
                                  size: 18,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'Arapça',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Stats Toggle
                        InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _showCounterStats = !_showCounterStats);
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            child: Row(
                              children: [
                                Icon(
                                  _showCounterStats ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                  color: _showCounterStats ? AppColors.gold500 : (isDark ? Colors.white38 : Colors.black38),
                                  size: 18,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'Sayaç',
                                  style: TextStyle(
                                    fontSize: 11,
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
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 3. Interactive Live Card Preview (Framed inside RepaintBoundary)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: maxPreviewHeight,
                ),
                child: RepaintBoundary(
                  key: _cardRepaintKey,
                  child: ZikirShareCardWidget(
                    zikirName: _activeZikirName,
                    arabicText: _activeArabicText,
                    virtue: _activeVirtue,
                    source: (_quoteIndex == 0) ? _activeSource : null,
                    specialDayGreeting: _selectedGreeting,
                    spiritualNote: activeSpiritualNote,
                    category: _activeCategory,
                    currentCount: widget.currentCount,
                    targetCount: widget.targetCount,
                    totalCount: widget.totalCount,
                    quoteIndex: _quoteIndex,
                    format: _selectedFormat,
                    theme: _selectedTheme,
                    typographyStyle: _selectedTypography,
                    patternStyle: _selectedPattern,
                    showCounterStats: _showCounterStats,
                    showArabicText: _showArabicText,
                    arabicFontFamily: widget.arabicFontFamily,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 4. Typography & Artistic Pattern Studio Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildSmallStudioChip(
                      label: 'Modern Yazı',
                      icon: Icons.text_format_rounded,
                      isSelected: _selectedTypography == ZikirShareTypographyStyle.modernOutfit,
                      onTap: () => setState(() => _selectedTypography = ZikirShareTypographyStyle.modernOutfit),
                      isDark: isDark,
                    ),
                    _buildSmallStudioChip(
                      label: 'Klasik Kitap',
                      icon: Icons.menu_book_rounded,
                      isSelected: _selectedTypography == ZikirShareTypographyStyle.classicAmiri,
                      onTap: () => setState(() => _selectedTypography = ZikirShareTypographyStyle.classicAmiri),
                      isDark: isDark,
                    ),
                    _buildSmallStudioChip(
                      label: 'Kitabe',
                      icon: Icons.account_balance_rounded,
                      isSelected: _selectedTypography == ZikirShareTypographyStyle.royalCinzel,
                      onTap: () => setState(() => _selectedTypography = ZikirShareTypographyStyle.royalCinzel),
                      isDark: isDark,
                    ),
                    Container(
                      width: 1,
                      height: 18,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      color: isDark ? Colors.white24 : Colors.black12,
                    ),
                    _buildSmallStudioChip(
                      label: 'Mihrap & Sufi',
                      icon: Icons.mosque_rounded,
                      isSelected: _selectedPattern == ZikirSharePatternStyle.mihrapSufi,
                      onTap: () => setState(() => _selectedPattern = ZikirSharePatternStyle.mihrapSufi),
                      isDark: isDark,
                    ),
                    _buildSmallStudioChip(
                      label: 'Selçuklu',
                      icon: Icons.star_border_purple500_rounded,
                      isSelected: _selectedPattern == ZikirSharePatternStyle.seljukStar,
                      onTap: () => setState(() => _selectedPattern = ZikirSharePatternStyle.seljukStar),
                      isDark: isDark,
                    ),
                    _buildSmallStudioChip(
                      label: 'Yalın Nur',
                      icon: Icons.blur_on_rounded,
                      isSelected: _selectedPattern == ZikirSharePatternStyle.minimalGlow,
                      onTap: () => setState(() => _selectedPattern = ZikirSharePatternStyle.minimalGlow),
                      isDark: isDark,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // 5. Special Day Greeting & Dua Note Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    ...IslamicSpecialDaysService.presetGreetings(isTurkish: isTurkish).map((preset) {
                      final isSelected = _selectedGreeting == preset.greeting;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(
                            preset.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: AppColors.gold500.withValues(alpha: 0.25),
                          onSelected: (_) {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedGreeting = preset.greeting);
                          },
                          visualDensity: VisualDensity.compact,
                        ),
                      );
                    }),
                    // Spiritual Dua Footer Toggle Chip
                    ChoiceChip(
                      label: Text(
                        _selectedNoteIndex == 0
                            ? '🤲 Dua Notu Ekle'
                            : '🤲 Dua Notu ($_selectedNoteIndex/${activeNoteList.length - 1})',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: _selectedNoteIndex > 0 ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      selected: _selectedNoteIndex > 0,
                      selectedColor: AppColors.gold500.withValues(alpha: 0.25),
                      onSelected: (_) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedNoteIndex = (_selectedNoteIndex + 1) % activeNoteList.length;
                        });
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // 6. Theme Palette Row
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 6),
                    child: Text(
                      'TEMA SEÇİMİ',
                      style: GoogleFonts.outfit(
                        fontSize: 10.5,
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
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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

              const SizedBox(height: 16),

              // Action Buttons
              SizedBox(
                width: double.infinity,
                height: 50,
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

              const SizedBox(height: 4),

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

  Widget _buildSmallStudioChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.gold500.withValues(alpha: 0.2)
                : (isDark ? const Color(0xFF1A232E) : const Color(0xFFF2F4F7)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.gold500 : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected ? AppColors.gold500 : (isDark ? Colors.white54 : Colors.black54),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? Colors.white : Colors.black87)
                      : (isDark ? Colors.white60 : Colors.black54),
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
