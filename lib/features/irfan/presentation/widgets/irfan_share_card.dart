import 'package:flutter/material.dart';
import 'irfan_seljuk_star_painter.dart';

enum IrfanShareFormat {
  story9x16,
  square1x1;

  Size get logicalSize => switch (this) {
        IrfanShareFormat.story9x16 => const Size(360, 640),
        IrfanShareFormat.square1x1 => const Size(360, 360),
      };
}

enum IrfanShareTheme {
  seljukEmerald,
  royalNightGold,
  parchmentNoor;

  List<Color> get gradientColors => switch (this) {
        IrfanShareTheme.seljukEmerald => const [
            Color(0xFF0E3B2E),
            Color(0xFF1B5E49),
            Color(0xFF0A261D),
          ],
        IrfanShareTheme.royalNightGold => const [
            Color(0xFF141824),
            Color(0xFF1F2738),
            Color(0xFF0E111A),
          ],
        IrfanShareTheme.parchmentNoor => const [
            Color(0xFFFBF6EC),
            Color(0xFFF2E7D3),
            Color(0xFFE9D9BE),
          ],
      };

  Color get primaryText => switch (this) {
        IrfanShareTheme.parchmentNoor => const Color(0xFF1E2B27),
        _ => const Color(0xFFF9F6F0),
      };

  Color get secondaryText => switch (this) {
        IrfanShareTheme.parchmentNoor => const Color(0xFF53635C),
        _ => const Color(0xFFD2DDD8),
      };

  Color get accentGold => switch (this) {
        IrfanShareTheme.parchmentNoor => const Color(0xFF9C6B30),
        _ => const Color(0xFFD4A574),
      };
}

/// İrfan Meydanı 9:16 Story & 1:1 Kare yüksek çözünürlüklü paylaşım kartı.
class IrfanShareCard extends StatelessWidget {
  final IrfanShareFormat format;
  final IrfanShareTheme theme;
  final String sessionTitle;
  final int correctCount;
  final int totalQuestions;
  final int streakDays;
  final String hikmetQuote;
  final String sourceRef;
  final bool isTurkish;

  const IrfanShareCard({
    super.key,
    required this.format,
    required this.theme,
    required this.sessionTitle,
    required this.correctCount,
    required this.totalQuestions,
    required this.streakDays,
    required this.hikmetQuote,
    required this.sourceRef,
    required this.isTurkish,
  });

  @override
  Widget build(BuildContext context) {
    final size = format.logicalSize;
    final isStory = format == IrfanShareFormat.story9x16;
    final gold = theme.accentGold;

    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.gradientColors,
        ),
      ),
      child: Stack(
        children: [
          // Selçuklu köşe filigranları
          Positioned(
            top: -36,
            right: -36,
            child: CustomPaint(
              size: const Size(150, 150),
              painter: IrfanSeljukStarPainter(
                color: gold.withValues(alpha: 0.16),
                accentColor: gold.withValues(alpha: 0.22),
                strokeWidth: 1.5,
                filled: true,
              ),
            ),
          ),
          Positioned(
            bottom: -44,
            left: -44,
            child: CustomPaint(
              size: const Size(168, 168),
              painter: IrfanSeljukStarPainter(
                color: gold.withValues(alpha: 0.13),
                accentColor: gold.withValues(alpha: 0.18),
                strokeWidth: 1.4,
                filled: true,
              ),
            ),
          ),
          // İç Tahrir Çerçevesi
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: gold.withValues(alpha: 0.42),
                  width: 1.2,
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 28,
              vertical: isStory ? 34 : 24,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Üst Başlık
                Column(
                  children: [
                    IrfanSeljukStarBadge(
                      size: isStory ? 46 : 32,
                      color: gold,
                      accentColor: gold,
                    ),
                    SizedBox(height: isStory ? 10 : 6),
                    Text(
                      isTurkish ? 'İRFAN MEYDANI' : 'WISDOM PLAZA',
                      style: TextStyle(
                        fontSize: isStory ? 12 : 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.2,
                        color: gold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sessionTitle,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isStory ? 17 : 14,
                        fontWeight: FontWeight.bold,
                        color: theme.primaryText,
                      ),
                    ),
                  ],
                ),

                // Orta Hikmet Alıntısı
                Flexible(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isStory ? 18 : 14,
                      vertical: isStory ? 20 : 12,
                    ),
                    decoration: BoxDecoration(
                      color: gold.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: gold.withValues(alpha: 0.30)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '“$hikmetQuote”',
                          textAlign: TextAlign.center,
                          maxLines: isStory ? 7 : 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isStory ? 14.5 : 12,
                            height: 1.48,
                            fontWeight: FontWeight.w500,
                            color: theme.primaryText,
                          ),
                        ),
                        SizedBox(height: isStory ? 12 : 6),
                        Text(
                          sourceRef,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isStory ? 11.5 : 10,
                            fontWeight: FontWeight.bold,
                            color: gold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Alt Skor ve Zikirce Mührü
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ShareStatPill(
                          label: isTurkish
                              ? '$correctCount/$totalQuestions Doğru'
                              : '$correctCount/$totalQuestions Correct',
                          gold: gold,
                          textColor: theme.primaryText,
                        ),
                        if (streakDays > 0) ...[
                          const SizedBox(width: 8),
                          _ShareStatPill(
                            label: isTurkish
                                ? '🔥 $streakDays Gün Seri'
                                : '🔥 $streakDays Day Streak',
                            gold: gold,
                            textColor: theme.primaryText,
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: isStory ? 14 : 8),
                    Text(
                      isTurkish
                          ? 'Zikirce • Sahih İlim & Zikir Rehberi'
                          : 'Zikirce • Authentic Knowledge & Dhikr',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                        color: theme.secondaryText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareStatPill extends StatelessWidget {
  final String label;
  final Color gold;
  final Color textColor;

  const _ShareStatPill({
    required this.label,
    required this.gold,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: gold.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gold.withValues(alpha: 0.42)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}
