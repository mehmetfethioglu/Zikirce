import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/hasibu_print_service.dart';
import '../providers/pdks_providers.dart';
import '../widgets/hasibu_theme_palette.dart';

/// Personel kartları, listeler ve raporlar için ortak yazdırma önizleme ve çıktı penceresi.
Future<void> showHasibuPrintPreviewDialog(
  BuildContext context,
  WidgetRef ref, {
  required PrintableDocument document,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _HasibuPrintPreviewDialog(document: document),
  );
}

class _HasibuPrintPreviewDialog extends ConsumerStatefulWidget {
  final PrintableDocument document;

  const _HasibuPrintPreviewDialog({required this.document});

  @override
  ConsumerState<_HasibuPrintPreviewDialog> createState() =>
      _HasibuPrintPreviewDialogState();
}

class _HasibuPrintPreviewDialogState
    extends ConsumerState<_HasibuPrintPreviewDialog> {
  late final ScrollController _scrollController;
  bool _isBusy = false;
  PrintDispatchResult? _lastResult;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handlePrint() async {
    setState(() => _isBusy = true);
    final res = await ref
        .read(hasibuPrintGatewayProvider)
        .printDocument(widget.document);
    if (!mounted) return;
    setState(() {
      _isBusy = false;
      _lastResult = res;
    });
  }

  Future<void> _handleSaveFile() async {
    setState(() => _isBusy = true);
    final res = await ref
        .read(hasibuPrintGatewayProvider)
        .savePrintableFile(widget.document);
    if (!mounted) return;
    setState(() {
      _isBusy = false;
      _lastResult = res;
    });
  }

  Future<void> _handleCopyText() async {
    await Clipboard.setData(
      ClipboardData(text: widget.document.plainTextSummary),
    );
    if (!mounted) return;
    setState(() {
      _lastResult = const PrintDispatchResult(
        success: true,
        message: 'Yazdırılabilir metin özeti panoya kopyalandı.',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final pal = HasibuPalette.of(context);
    final doc = widget.document;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.print_rounded, color: Color(0xFF0284C7)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  doc.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: pal.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  doc.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: pal.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              doc.landscape ? 'A4 Yatay' : 'A4 Dikey',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0284C7),
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: (MediaQuery.sizeOf(context).width - 64).clamp(280.0, 680.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'A4 yazıcı çıktısı veya PDF olarak kaydetmek için "Yazdır" düğmesini kullanabilirsiniz.',
              style: TextStyle(fontSize: 12, color: pal.textSecondary),
            ),
            const SizedBox(height: 10),
            Container(
              height: 280,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: pal.subtle,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: pal.border),
              ),
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: SelectableText(
                    doc.plainTextSummary,
                    style: TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 11.5,
                      color: pal.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
            if (_lastResult != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: (_lastResult!.success
                          ? const Color(0xFF059669)
                          : const Color(0xFFDC2626))
                      .withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (_lastResult!.success
                            ? const Color(0xFF059669)
                            : const Color(0xFFDC2626))
                        .withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  _lastResult!.message,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _lastResult!.success
                        ? const Color(0xFF059669)
                        : const Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Kapat'),
        ),
        OutlinedButton.icon(
          key: const ValueKey('print_dialog_copy_text_button'),
          onPressed: _isBusy ? null : _handleCopyText,
          icon: const Icon(Icons.copy_all_rounded, size: 16),
          label: const Text('Metni Kopyala'),
        ),
        OutlinedButton.icon(
          key: const ValueKey('print_dialog_save_html_button'),
          onPressed: _isBusy ? null : _handleSaveFile,
          icon: const Icon(Icons.save_alt_rounded, size: 16),
          label: const Text('Belgeyi Kaydet'),
        ),
        FilledButton.icon(
          key: const ValueKey('print_dialog_execute_button'),
          onPressed: _isBusy ? null : _handlePrint,
          icon: const Icon(Icons.print_rounded, size: 16),
          label: Text(_isBusy ? 'Hazırlanıyor...' : 'Yazdır'),
        ),
      ],
    );
  }
}
