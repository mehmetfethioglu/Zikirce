import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Amiri Font, 2.0x Satır Aralığı ve Sağa Yaslı Özel Arapça Metin Kartı
class ArabicBlockCard extends StatelessWidget {
  final String arabicText;
  final double baseFontSize;
  final VoidCallback? onPlayTts;

  const ArabicBlockCard({
    super.key,
    required this.arabicText,
    this.baseFontSize = 18.0,
    this.onPlayTts,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surface.withValues(alpha: 0.7)
            : const Color(0xFFFAF6EE), // Sıcak parşömen tonu
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Kart Başlığı & Aksiyon İkonları
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_stories_rounded,
                    size: 15,
                    color: theme.colorScheme.primary.withValues(alpha: 0.85),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Arapça Metin / Hadîs-i Şerîf',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary.withValues(alpha: 0.9),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 15),
                    tooltip: 'Metni Kopyala',
                    visualDensity: VisualDensity.compact,
                    splashRadius: 16,
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
                      splashRadius: 16,
                      onPressed: onPlayTts,
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Amiri Fontu & 2.0x Harekeleri Birbirine Bindirmeyen Satır Aralığı
          Directionality(
            textDirection: TextDirection.rtl,
            child: SelectableText(
              arabicText,
              textAlign: TextAlign.right,
              style: GoogleFonts.amiri(
                fontSize: baseFontSize + 4,
                height: 2.0, // Kritik: 2.0x aralık üst ve alt harekelerin çarpışmasını engeller
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
