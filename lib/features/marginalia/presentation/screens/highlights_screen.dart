import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../domain/entities/highlight_entity.dart';
import '../../services/qr_p2p_sync_service.dart';
import '../widgets/qr_sync_modal.dart';
import '../widgets/quote_studio_sheet.dart';

class HighlightsScreen extends ConsumerStatefulWidget {
  const HighlightsScreen({super.key});

  @override
  ConsumerState<HighlightsScreen> createState() => _HighlightsScreenState();
}

class _HighlightsScreenState extends ConsumerState<HighlightsScreen> {
  List<HighlightEntity> _highlights = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHighlights();
  }

  Future<void> _loadHighlights() async {
    final repo = ref.read(highlightRepositoryProvider);
    final res = await repo.getAllHighlights();
    if (mounted) {
      setState(() {
        _highlights = res.dataOrNull ?? [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlightRepo = ref.read(highlightRepositoryProvider);
    final qrService = QrP2pSyncService(highlightRepo);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Şerh & Not Defteri',
          style: GoogleFonts.literata(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Çevrimdışı QR Not Takası',
            icon: const Icon(Icons.qr_code_2),
            onPressed: () => QrSyncModal.show(context, qrService),
          ),
          IconButton(
            tooltip: 'Markdown Dışa Aktar (Obsidian/Notion)',
            icon: const Icon(Icons.download),
            onPressed: () async {
              final mdRes = await highlightRepo.exportHighlightsToMarkdown();
              if (mdRes.isSuccess && mdRes.dataOrNull != null) {
                Share.share(mdRes.dataOrNull!, subject: 'Tahrir Şerh Arşivi.md');
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _highlights.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('✍️', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      Text(
                        'Henüz bir şerh veya not kaydedilmedi.',
                        style: GoogleFonts.literata(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Okuma ekranında metni seçip "Şerh Düş" eylemini kullanabilirsiniz.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _highlights.length,
                  itemBuilder: (context, index) {
                    final h = _highlights[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    h.category.displayName,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                                Text(
                                  'Sayfa ${h.pageNumber}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '“${h.selectedText}”',
                              style: GoogleFonts.literata(
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                                height: 1.5,
                              ),
                            ),
                            if (h.userNote != null && h.userNote!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  border: Border.all(color: theme.colorScheme.outline),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '✍️ Not: ${h.userNote}',
                                  style: GoogleFonts.inter(fontSize: 12, height: 1.4),
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  icon: const Icon(Icons.share, size: 16),
                                  label: const Text('Alıntı Kartı'),
                                  onPressed: () {
                                    QuoteStudioSheet.show(
                                      context,
                                      quoteText: h.selectedText,
                                      bookTitle: 'Tahrir Kitaplığı',
                                      author: 'Yazar',
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20),
                                  onPressed: () async {
                                    if (h.id != null) {
                                      await highlightRepo.deleteHighlight(h.id!);
                                      _loadHighlights();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
