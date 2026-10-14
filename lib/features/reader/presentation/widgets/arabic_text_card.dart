import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/theme_provider.dart';

class ArabicTextCard extends StatelessWidget {
  final String arabicText;
  final ReaderThemeState themeState;
  final VoidCallback? onPlayTts;

  const ArabicTextCard({
    super.key,
    required this.arabicText,
    required this.themeState,
    this.onPlayTts,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 14),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surface.withValues(alpha: 0.7)
            : theme.colorScheme.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.20),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Header with Calligraphy Icon and Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.menu_book_rounded,
                    size: 15,
                    color: theme.colorScheme.primary.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Arapça Metin / Hadîs-i Şerîf',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary.withValues(alpha: 0.85),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    tooltip: 'Arapça Metni Kopyala',
                    visualDensity: VisualDensity.compact,
                    splashRadius: 18,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: arabicText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✨ Arapça metin panoya kopyalandı.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  if (onPlayTts != null)
                    IconButton(
                      icon: const Icon(Icons.volume_up_rounded, size: 16),
                      tooltip: 'Seslendir',
                      visualDensity: VisualDensity.compact,
                      splashRadius: 18,
                      onPressed: onPlayTts,
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Main Arabic Text with Amiri Font & RTL Directionality
          Directionality(
            textDirection: TextDirection.rtl,
            child: SelectableText(
              arabicText,
              textAlign: TextAlign.right,
              style: GoogleFonts.amiri(
                fontSize: themeState.fontSize + 4,
                height: 2.0, // generous line-height prevents diacritics (harakat) collision
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
