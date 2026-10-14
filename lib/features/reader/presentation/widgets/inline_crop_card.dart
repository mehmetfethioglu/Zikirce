import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_view/photo_view.dart';
import 'image_lightbox_modal.dart';

/// Düşük Güven Skorlu / Süslü Hat Blokları İçin Pinch-to-Zoom Lightbox Kartı
class InlineCropCard extends StatelessWidget {
  final String? imagePath;
  final Uint8List? imageBytes;
  final String? caption;
  final VoidCallback? onSwitchToOriginalPdf;

  const InlineCropCard({
    super.key,
    this.imagePath,
    this.imageBytes,
    this.caption,
    this.onSwitchToOriginalPdf,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasFile = imagePath != null && File(imagePath!).existsSync();
    final hasBytes = imageBytes != null && imageBytes!.isNotEmpty;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surface
            : theme.colorScheme.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.20),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (hasBytes) {
              _openPinchToZoomLightboxFromBytes(context);
            } else if (hasFile) {
              ImageLightboxModal.show(
                context,
                imageSource: imagePath!,
                caption: caption ?? 'Kaligrafi / Sayfa Kesiti',
              );
            } else if (onSwitchToOriginalPdf != null) {
              onSwitchToOriginalPdf!();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.draw_rounded,
                      size: 14,
                      color: theme.colorScheme.primary.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      caption ?? '📜 Orijinal Kaligrafi / Başlık Kesiti',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.zoom_in_rounded,
                      size: 14,
                      color: theme.colorScheme.primary.withValues(alpha: 0.6),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (hasBytes)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      imageBytes!,
                      fit: BoxFit.contain,
                      width: double.infinity,
                    ),
                  )
                else if (hasFile)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(imagePath!),
                      fit: BoxFit.contain,
                      width: double.infinity,
                    ),
                  )
                else
                  _buildPlaceholder(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.brush_rounded,
            size: 28,
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 6),
          Text(
            'Süslü Hat / Başlık Orijinal Görünümde',
            style: GoogleFonts.literata(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Yüksek çözünürlükte incelemek için dokunun',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  /// Tam Ekran Çift Parmak Yakınlaştırma (Pinch-to-Zoom Lightbox)
  void _openPinchToZoomLightboxFromBytes(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            title: Text(
              caption ?? 'Kaligrafi İnceleme',
              style: GoogleFonts.inter(fontSize: 14, color: Colors.white70),
            ),
          ),
          body: Center(
            child: PhotoView(
              imageProvider: MemoryImage(imageBytes!),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 3.5,
              backgroundDecoration: const BoxDecoration(color: Colors.black),
            ),
          ),
        ),
      ),
    );
  }
}
