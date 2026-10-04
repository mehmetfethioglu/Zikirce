import 'package:flutter/material.dart';
import '../../../../core/constants/surah_data_provider.dart';

class TalimPageSelectionBottomSheet extends StatefulWidget {
  final String modeKey;
  final String modeTitle;
  final String modeIcon;
  final Color modeColor;
  final int initialPage;

  const TalimPageSelectionBottomSheet({
    super.key,
    required this.modeKey,
    required this.modeTitle,
    required this.modeIcon,
    required this.modeColor,
    this.initialPage = 1,
  });

  @override
  State<TalimPageSelectionBottomSheet> createState() => _TalimPageSelectionBottomSheetState();
}

class _TalimPageSelectionBottomSheetState extends State<TalimPageSelectionBottomSheet> {
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage.clamp(1, 605);
  }

  void _setPage(int p) {
    setState(() {
      _currentPage = p.clamp(1, 605);
    });
  }

  String _getPageInfo(int page) {
    final juz = SurahDataProvider.getJuzForPage(page);
    // Find closest surah at or before this page
    SureItem? currentSurah;
    for (final s in SurahDataProvider.surahs) {
      if (s.startPage <= page) {
        currentSurah = s;
      } else {
        break;
      }
    }
    final surahName = currentSurah?.name ?? 'Fâtiha';
    return '$juz. Cüz · $surahName Sûresi';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF1F1A17) : const Color(0xFFFFFFFF);
    final primaryTextColor = isDark ? const Color(0xFFE8DDD0) : const Color(0xFF1E2B27);
    final secondaryTextColor = isDark ? const Color(0xFFA89888) : const Color(0xFF506861);
    final cardBg = isDark ? const Color(0xFF2A2520) : const Color(0xFFF4F8F6);
    final borderStroke = isDark ? const Color(0xFF3A3530) : const Color(0xFFD8E5E1);

    final infoText = _getPageInfo(_currentPage);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.only(top: 12, left: 20, right: 20, bottom: 16),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: borderStroke,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header with Icon, Title & Close Button
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: widget.modeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(widget.modeIcon, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.modeTitle,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Çalışmak istediğiniz Kur\'an sayfasını seçin',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: borderStroke.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: Icon(Icons.close_rounded, size: 18, color: primaryTextColor),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Quick Shortcut Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickChip('📌', 'Son Okunan', 1, cardBg, borderStroke, primaryTextColor),
                const SizedBox(width: 8),
                _buildQuickChip('🎯', 'Ezber Hedefim', 582, cardBg, borderStroke, primaryTextColor),
                const SizedBox(width: 8),
                _buildQuickChip('📖', '1. Cüz', 1, cardBg, borderStroke, primaryTextColor),
                const SizedBox(width: 8),
                _buildQuickChip('✨', '30. Cüz', 582, cardBg, borderStroke, primaryTextColor),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Page Selector Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: borderStroke),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Decrement Button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _setPage(_currentPage - 1),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: borderStroke.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: Icon(Icons.remove_rounded, color: primaryTextColor, size: 20),
                        ),
                      ),
                    ),

                    // Number & Info
                    Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              'Sayfa ',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: secondaryTextColor,
                              ),
                            ),
                            Text(
                              '$_currentPage',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: widget.modeColor,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          infoText,
                          style: TextStyle(
                            fontSize: 11,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),

                    // Increment Button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _setPage(_currentPage + 1),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: borderStroke.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: Icon(Icons.add_rounded, color: primaryTextColor, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Slider
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: widget.modeColor,
                    inactiveTrackColor: widget.modeColor.withOpacity(0.2),
                    thumbColor: widget.modeColor,
                    overlayColor: widget.modeColor.withOpacity(0.15),
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  ),
                  child: Slider(
                    value: _currentPage.toDouble(),
                    min: 1,
                    max: 605,
                    onChanged: (val) {
                      _setPage(val.round());
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Start Practice CTA Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.modeColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 4,
              shadowColor: widget.modeColor.withOpacity(0.4),
            ),
            onPressed: () {
              Navigator.of(context).pop(_currentPage);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${widget.modeTitle}nı Başlat (Sayfa $_currentPage)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildQuickChip(
    String emoji,
    String label,
    int page,
    Color bg,
    Color stroke,
    Color textColor,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _setPage(page),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: stroke),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
