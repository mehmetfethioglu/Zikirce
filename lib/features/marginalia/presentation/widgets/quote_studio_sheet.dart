import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_colors.dart';

enum QuoteTemplate { story, square, parchment }

class QuoteStudioSheet extends StatefulWidget {
  final String quoteText;
  final String bookTitle;
  final String author;

  const QuoteStudioSheet({
    super.key,
    required this.quoteText,
    required this.bookTitle,
    required this.author,
  });

  static void show(
    BuildContext context, {
    required String quoteText,
    required String bookTitle,
    required String author,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => QuoteStudioSheet(
        quoteText: quoteText,
        bookTitle: bookTitle,
        author: author,
      ),
    );
  }

  @override
  State<QuoteStudioSheet> createState() => _QuoteStudioSheetState();
}

class _QuoteStudioSheetState extends State<QuoteStudioSheet> {
  QuoteTemplate _selectedTemplate = QuoteTemplate.parchment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '✨ Tahrir Alıntı Stüdyosu',
                style: GoogleFonts.literata(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),

              // Template Selector
              SegmentedButton<QuoteTemplate>(
                segments: const [
                  ButtonSegment(value: QuoteTemplate.parchment, label: Text('Parşömen')),
                  ButtonSegment(value: QuoteTemplate.story, label: Text('Story (9:16)')),
                  ButtonSegment(value: QuoteTemplate.square, label: Text('Kare (1:1)')),
                ],
                selected: {_selectedTemplate},
                onSelectionChanged: (set) => setState(() => _selectedTemplate = set.first),
              ),
              const SizedBox(height: 20),

              // Live Preview Card
              _buildPreviewCard(),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy),
                      label: const Text('Metni Kopyala'),
                      onPressed: () {
                        Share.share('"${widget.quoteText}"\n— ${widget.author}, ${widget.bookTitle} (Tahrir ile)');
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.share),
                      label: const Text('Paylaş'),
                      onPressed: () {
                        Share.share('"${widget.quoteText}"\n\n— ${widget.author}, ${widget.bookTitle}\n📜 Tahrir Okuma Ekosistemi');
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    return switch (_selectedTemplate) {
      QuoteTemplate.parchment => Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.parchmentBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.parchmentBorder, width: 2),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
            ],
          ),
          child: Column(
            children: [
              Text(
                '“',
                style: GoogleFonts.literata(
                  fontSize: 48,
                  height: 0.8,
                  color: AppColors.parchmentAccent,
                ),
              ),
              Text(
                widget.quoteText,
                textAlign: TextAlign.center,
                style: GoogleFonts.literata(
                  fontSize: 16,
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                  color: AppColors.parchmentText,
                ),
              ),
              const SizedBox(height: 16),
              Container(width: 40, height: 1, color: AppColors.parchmentAccent.withOpacity(0.5)),
              const SizedBox(height: 12),
              Text(
                widget.author,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.parchmentText,
                ),
              ),
              Text(
                widget.bookTitle,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.parchmentSecondary,
                ),
              ),
            ],
          ),
        ),

      QuoteTemplate.story => Container(
          width: 220,
          height: 330,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('📜', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Text(
                    'TAHRİR',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              Text(
                '“${widget.quoteText}”',
                textAlign: TextAlign.center,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.literata(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.white,
                  fontStyle: FontStyle.italic,
                ),
              ),
              Column(
                children: [
                  Text(
                    widget.author,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.amberGold,
                    ),
                  ),
                  Text(
                    widget.bookTitle,
                    style: GoogleFonts.inter(fontSize: 10, color: Colors.white60),
                  ),
                ],
              ),
            ],
          ),
        ),

      QuoteTemplate.square => Container(
          width: 250,
          height: 250,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '“${widget.quoteText}”',
                textAlign: TextAlign.center,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.lora(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '— ${widget.author}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
    };
  }
}
