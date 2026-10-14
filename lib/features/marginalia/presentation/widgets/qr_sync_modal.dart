import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/qr_p2p_sync_service.dart';

class QrSyncModal extends StatefulWidget {
  final QrP2pSyncService syncService;
  final int? bookId;

  const QrSyncModal({super.key, required this.syncService, this.bookId});

  static void show(BuildContext context, QrP2pSyncService service, {int? bookId}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => QrSyncModal(syncService: service, bookId: bookId),
    );
  }

  @override
  State<QrSyncModal> createState() => _QrSyncModalState();
}

class _QrSyncModalState extends State<QrSyncModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _qrPayload;
  bool _isLoading = true;
  String? _scanMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPayload();
  }

  Future<void> _loadPayload() async {
    final res = await widget.syncService.generateSharePayload(bookId: widget.bookId);
    if (mounted) {
      setState(() {
        _qrPayload = res.dataOrNull ?? '[]';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Container(
        height: 520,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '📡 Çevrimdışı P2P Şerh Takası',
              style: GoogleFonts.literata(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.qr_code), text: 'Şerhleri Paylaş (QR)'),
                Tab(icon: Icon(Icons.qr_code_scanner), text: 'QR İle İçe Aktar'),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: QR Generator
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: theme.colorScheme.outline),
                                ),
                                child: QrImageView(
                                  data: _qrPayload ?? 'TAHRIR',
                                  version: QrVersions.auto,
                                  size: 210.0,
                                  backgroundColor: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Arkadaşınız bu QR kodu tarayarak notlarınızı anında kendi Tahrir kütüphanesine alabilir.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                              ),
                            ],
                          ),
                        ),

                  // Tab 2: QR Scanner
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        MobileScanner(
                          onDetect: (capture) async {
                            final barcodes = capture.barcodes;
                            for (final barcode in barcodes) {
                              final rawVal = barcode.rawValue;
                              if (rawVal != null && rawVal.isNotEmpty) {
                                final countRes = await widget.syncService.importFromPayload(rawVal);
                                if (mounted) {
                                  setState(() {
                                    _scanMessage = countRes.isSuccess
                                        ? '🎉 ${countRes.dataOrNull} adet şerh başarıyla içe aktarıldı!'
                                        : 'Hata: ${countRes.errorOrNull?.message}';
                                  });
                                }
                                break;
                              }
                            }
                          },
                        ),
                        if (_scanMessage != null)
                          Positioned(
                            bottom: 16,
                            left: 16,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _scanMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
