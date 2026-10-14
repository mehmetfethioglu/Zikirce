import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/content_block.dart';
import 'snippet_lightbox_sheet.dart';

/// Sayfa başında doğrudan görsel olarak duracak kırpılmış kaligrafik başlık widget'ı
class CalligraphyHeaderWidget extends StatelessWidget {
  final CalligraphyHeaderBlock headerBlock;

  const CalligraphyHeaderWidget({
    super.key,
    required this.headerBlock,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasFile = headerBlock.croppedImagePath.isNotEmpty && File(headerBlock.croppedImagePath).existsSync();
    final hasBytes = headerBlock.rawBytes != null && headerBlock.rawBytes!.isNotEmpty;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8, bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.20),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.05),
            blurRadius: 16,
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
            SnippetLightboxSheet.show(
              context,
              snippet: InteractiveSnippetBlock(
                type: SnippetType.calligraphyTitle,
                title: headerBlock.title,
                croppedImagePath: headerBlock.croppedImagePath,
                rawBytes: headerBlock.rawBytes,
                boundingBox: headerBlock.boundingBox,
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (hasBytes)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      headerBlock.rawBytes!,
                      fit: BoxFit.contain,
                      width: double.infinity,
                    ),
                  )
                else if (hasFile)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(headerBlock.croppedImagePath),
                      fit: BoxFit.contain,
                      width: double.infinity,
                    ),
                  )
                else
                  Text(
                    headerBlock.title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.literata(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.auto_stories_rounded,
                      size: 12,
                      color: theme.colorScheme.primary.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Orijinal Kaligrafik Başlık Kesiti (300 DPI)',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
