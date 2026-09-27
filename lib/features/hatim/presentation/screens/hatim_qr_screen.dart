import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/database/app_database.dart';

class HatimQrDisplayScreen extends StatelessWidget {
  final Hatim hatim;

  const HatimQrDisplayScreen({super.key, required this.hatim});

  @override
  Widget build(BuildContext context) {
    final qrData = 'zikirce://hatim?id=${hatim.id}&title=${Uri.encodeComponent(hatim.title)}';

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        title: Text('Grup Hatmi QR Paylaşımı', style: AppTypography.headingSmall(color: Colors.white)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold500.withOpacity(0.2),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 220.0,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                hatim.title,
                style: AppTypography.headingMedium(color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                'Arkadaşlarınız bu QR kodu Zikirce ile okutarak hatme anında katılabilir.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8A9BAE), fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HatimQrScannerScreen extends StatefulWidget {
  const HatimQrScannerScreen({super.key});

  @override
  State<HatimQrScannerScreen> createState() => _HatimQrScannerScreenState();
}

class _HatimQrScannerScreenState extends State<HatimQrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Hatim QR Tara', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_isScanned) return;
              final barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final raw = barcode.rawValue;
                if (raw != null && raw.startsWith('zikirce://hatim')) {
                  _isScanned = true;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Grup hatmine başarıyla katıldınız!')),
                  );
                  Navigator.of(context).pop();
                  break;
                }
              }
            },
          ),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.gold400, width: 2.5),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
