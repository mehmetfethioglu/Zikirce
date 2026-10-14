import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/content_block.dart';

/// Sorunlu alanların (Arapça hat, tablo, şema, dipnot) 300 DPI yüksek netlikteki
/// orijinal görselini çift parmakla yakınlaştırılabilir (pinch-to-zoom) olarak sunan Lightbox modalı
class SnippetLightboxSheet extends StatelessWidget {
  final InteractiveSnippetBlock snippet;

  const SnippetLightboxSheet({
    super.key,
    required this.snippet,
  });

  static void show(BuildContext context, {required InteractiveSnippetBlock snippet}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SnippetLightboxSheet(snippet: snippet),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final media = MediaQuery.of(context);

    final hasFile = snippet.croppedImagePath.isNotEmpty && File(snippet.croppedImagePath).existsSync();
    final hasBytes = snippet.rawBytes != null && snippet.rawBytes!.isNotEmpty;

    return Container(
      height: media.size.height * 0.82,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141416) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    snippet.badgeIcon,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        snippet.title,
                        style: GoogleFonts.literata(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        snippet.subtitle ?? '300 DPI Orijinal Vektörel Sayfa Kesiti',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Kapat',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // InteractiveViewer Pinch-to-Zoom Image Area
          Expanded(
            child: Container(
              color: isDark ? Colors.black : const Color(0xFFF7F7F8),
              child: ClipRect(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 5.0,
                  boundaryMargin: const EdgeInsets.all(24),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: hasBytes
                          ? Image.memory(
                              snippet.rawBytes!,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                            )
                          : hasFile
                              ? Image.file(
                                  File(snippet.croppedImagePath),
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.high,
                                )
                              : _buildFallbackView(theme),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Bottom Bar & Fallback Text actions
          Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20, media.padding.bottom + 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF18181A) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.pinch_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 6),
                Text(
                  'Çift parmakla yakınlaştırın (Zoom)',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const Spacer(),
                if (snippet.fallbackText != null && snippet.fallbackText!.isNotEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Metni Kopyala'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: snippet.fallbackText!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('📋 Metin panoya kopyalandı!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackView(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(snippet.badgeIcon, size: 40, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            snippet.title,
            style: GoogleFonts.literata(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (snippet.fallbackText != null) ...[
            const SizedBox(height: 8),
            Text(
              snippet.fallbackText!,
              textAlign: TextAlign.center,
              style: GoogleFonts.amiri(
                fontSize: 17,
                height: 1.8,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
