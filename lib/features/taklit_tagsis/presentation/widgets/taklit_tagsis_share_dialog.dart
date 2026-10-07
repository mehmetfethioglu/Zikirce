import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/taklit_tagsis_service.dart';

class TaklitTagsisShareDialog extends StatefulWidget {
  final TaklitTagsisBrandGroup brandGroup;

  const TaklitTagsisShareDialog({
    super.key,
    required this.brandGroup,
  });

  /// Opens the visual share dialog modal.
  static Future<void> show(BuildContext context, TaklitTagsisBrandGroup brandGroup) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TaklitTagsisShareDialog(brandGroup: brandGroup),
    );
  }

  @override
  State<TaklitTagsisShareDialog> createState() => _TaklitTagsisShareDialogState();
}

class _TaklitTagsisShareDialogState extends State<TaklitTagsisShareDialog> {
  final GlobalKey _cardKey = GlobalKey();
  bool _isStoryFormat = false; // false: 1:1 Square/Chat, true: 9:16 Story
  bool _isExporting = false;

  String _formatDate(DateTime dt) {
    const months = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  Future<Uint8List?> _captureCardBytes() async {
    try {
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Capture error: $e');
      return null;
    }
  }

  String _buildShareCaption() {
    final g = widget.brandGroup;
    final String statusText = g.hasHealthHazard
        ? '🚨 SAĞLIĞI TEHLİKEYE DÜŞÜREN GIDA'
        : '⚠️ TAKLİT VEYA TAĞŞİŞ HİLESİ';

    return '''
$statusText
🏛️ T.C. Tarım ve Orman Bakanlığı Resmi Kara Liste İkazı

Marka: ${g.brandName}
Firma: ${g.companyName}
Uygunsuzluk: ${g.primaryReasonSummary}
Hileli Ürün Sayısı: ${g.productCount} Adet

Gıdalarınızı tüketmeden önce kontrol edin!
#OrganicScore #TarımBakanlığı #GüvenilirGıda
'''.trim();
  }

  Future<void> _shareImage() async {
    setState(() => _isExporting = true);
    final bytes = await _captureCardBytes();
    if (bytes == null) {
      setState(() => _isExporting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Görsel oluşturulamadı, lütfen tekrar deneyin.')),
        );
      }
      return;
    }

    try {
      final tempDir = Directory.systemTemp;
      final fileName = 'bakanlik_ikaz_${widget.brandGroup.brandName.replaceAll(RegExp(r'\s+'), '_')}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      setState(() => _isExporting = false);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: _buildShareCaption(),
      );
    } catch (e) {
      setState(() => _isExporting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Paylaşım hatası: $e')),
        );
      }
    }
  }

  Future<void> _saveImage() async {
    setState(() => _isExporting = true);
    final bytes = await _captureCardBytes();
    if (bytes == null) {
      setState(() => _isExporting = false);
      return;
    }

    try {
      final cleanName = widget.brandGroup.brandName.replaceAll(RegExp(r'[^\w]'), '_');
      final fileName = 'Bakanlik_Ikaz_${cleanName}_${DateTime.now().millisecondsSinceEpoch}.png';

      // Save to Android Downloads or app temp
      Directory? targetDir;
      final androidDownload = Directory('/storage/emulated/0/Download');
      if (androidDownload.existsSync()) {
        targetDir = androidDownload;
      } else {
        targetDir = Directory.systemTemp;
      }

      final file = File('${targetDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      setState(() => _isExporting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Görsel cihaza kaydedildi: ${targetDir.path == Directory.systemTemp.path ? "Geçici Klasör" : "İndirilenler (Download)"}'),
            backgroundColor: AppColors.primaryEmerald,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _isExporting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kaydetme hatası: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = context.surfaceColor;
    final borderColor = context.cardBorderColor;
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;

    final g = widget.brandGroup;
    final bool isHazard = g.hasHealthHazard;
    final Color badgeColor = isHazard ? AppColors.dangerRed : AppColors.cautionGold;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.94,
      ),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          // Drag indicator
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Header Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.photo_library_rounded, color: badgeColor, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Görsel İkaz Kartı Paylaş',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Format Toggle: 1:1 Kare / 9:16 Hikaye
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: textSecondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isStoryFormat = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: !_isStoryFormat ? surfaceColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: !_isStoryFormat
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.crop_square_rounded,
                              size: 16,
                              color: !_isStoryFormat ? badgeColor : textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Kare / Sohbet (1:1)',
                              style: TextStyle(
                                color: !_isStoryFormat ? textPrimary : textSecondary,
                                fontSize: 12,
                                fontWeight: !_isStoryFormat ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isStoryFormat = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _isStoryFormat ? surfaceColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: _isStoryFormat
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.stay_current_portrait_rounded,
                              size: 16,
                              color: _isStoryFormat ? badgeColor : textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Hikaye (9:16)',
                              style: TextStyle(
                                color: _isStoryFormat ? textPrimary : textSecondary,
                                fontSize: 12,
                                fontWeight: _isStoryFormat ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Scrollable Card Preview Container
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Center(
                child: RepaintBoundary(
                  key: _cardKey,
                  child: _buildVisualCard(badgeColor, isHazard),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Actions Row (Share & Save)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              children: [
                // Save to Gallery button
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textPrimary,
                        side: BorderSide(color: borderColor, width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _isExporting ? null : _saveImage,
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text(
                        'Görseli Kaydet',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Share Image button
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: badgeColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _isExporting ? null : _shareImage,
                      icon: _isExporting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.share_rounded, size: 18),
                      label: Text(
                        _isExporting ? 'Hazırlanıyor...' : 'Görseli Paylaş (WhatsApp/Story)',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualCard(Color badgeColor, bool isHazard) {
    final g = widget.brandGroup;
    final double cardWidth = 340;
    final double cardHeight = _isStoryFormat ? 604 : 350;

    return Container(
      width: cardWidth,
      height: cardHeight,
      padding: EdgeInsets.symmetric(
        horizontal: _isStoryFormat ? 20 : 16,
        vertical: _isStoryFormat ? 20 : 14,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: badgeColor.withValues(alpha: 0.75), width: 1.8),
        gradient: LinearGradient(
          colors: isHazard
              ? const [
                  Color(0xFF260808),
                  Color(0xFF140404),
                  Color(0xFF1F0606),
                  Color(0xFF0C0202),
                ]
              : const [
                  Color(0xFF241905),
                  Color(0xFF130D02),
                  Color(0xFF1D1403),
                  Color(0xFF0C0801),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.35, 0.75, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withValues(alpha: 0.28),
            blurRadius: 28,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. Official Ministry Header
          Row(
            children: [
              Container(
                width: _isStoryFormat ? 38 : 32,
                height: _isStoryFormat ? 38 : 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: badgeColor.withValues(alpha: 0.16),
                  border: Border.all(color: badgeColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: badgeColor.withValues(alpha: 0.25),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    isHazard ? Icons.gavel_rounded : Icons.shield_rounded,
                    color: badgeColor,
                    size: _isStoryFormat ? 20 : 16,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'T.C. TARIM VE ORMAN BAKANLIĞI',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: _isStoryFormat ? 11.5 : 10,
                        letterSpacing: 0.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'RESMİ KAMUOYU DUYURUSU • 5996 SAYILI KANUN',
                      style: TextStyle(
                        color: badgeColor,
                        fontSize: _isStoryFormat ? 8.5 : 7.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: _isStoryFormat ? 7 : 6,
                  vertical: _isStoryFormat ? 3.5 : 2.5,
                ),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.45)),
                ),
                child: Text(
                  _formatDate(g.latestAnnouncedAt),
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: _isStoryFormat ? 9.5 : 8.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          // 2. Brand & Producer Section (Wraps cleanly without truncation!)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                g.brandName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: _isStoryFormat
                      ? (g.brandName.length > 25 ? 19 : 22)
                      : (g.brandName.length > 25 ? 15.5 : 17.5),
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                  height: 1.15,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.domain_rounded,
                      size: _isStoryFormat ? 13 : 11,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      g.companyName,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: _isStoryFormat ? 11 : 9.5,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                      ),
                      maxLines: _isStoryFormat ? 3 : 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 3. Central Hazard Box (Violation Callout)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(_isStoryFormat ? 13 : 10),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: badgeColor.withValues(alpha: 0.55), width: 1.4),
              boxShadow: [
                BoxShadow(
                  color: badgeColor.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      isHazard ? Icons.dangerous_rounded : Icons.report_problem_rounded,
                      color: badgeColor,
                      size: _isStoryFormat ? 17 : 14,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isHazard
                            ? 'SAĞLIĞI TEHLİKEYE DÜŞÜREN GIDA'
                            : 'TAKLİT VEYA TAĞŞİŞ TESPİTİ',
                        style: TextStyle(
                          color: badgeColor,
                          fontWeight: FontWeight.w900,
                          fontSize: _isStoryFormat ? 11 : 9.5,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: _isStoryFormat ? 7 : 4),
                Text(
                  'TESPİT EDİLEN UYGUNSUZLUK:',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: _isStoryFormat ? 9.5 : 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  g.uniqueReasons.isNotEmpty
                      ? g.uniqueReasons.join(' • ')
                      : g.primaryReasonSummary,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: _isStoryFormat ? 14 : 12,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                  maxLines: _isStoryFormat ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // 4. Affected Products Preview
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(_isStoryFormat ? 12 : 9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Category & Count Row (Dedicated space, no collision)
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.inventory_2_outlined, size: 10.5, color: badgeColor),
                                const SizedBox(width: 4),
                                ConstrainedBox(
                                  constraints: BoxConstraints(maxWidth: cardWidth * 0.45),
                                  child: Text(
                                    g.primaryCategory,
                                    style: TextStyle(
                                      color: badgeColor,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${g.productCount} Kusurlu Ürün',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: _isStoryFormat ? 8 : 4),
                // Products List
                ...g.products.take(_isStoryFormat ? 3 : 1).map((p) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: _isStoryFormat ? 4 : 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(Icons.arrow_right_rounded, size: 14, color: badgeColor),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            p.productName,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: _isStoryFormat ? 11 : 10,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (g.products.length > (_isStoryFormat ? 3 : 1))
                  Padding(
                    padding: const EdgeInsets.only(left: 14, top: 2),
                    child: Text(
                      '+${g.products.length - (_isStoryFormat ? 3 : 1)} diğer hileli ürün daha listede...',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 9,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 5. Extra Enrichment for 9:16 Story (Fills the canvas elegantly!)
          if (_isStoryFormat) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.035),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.verified_user_outlined, size: 16, color: badgeColor.withValues(alpha: 0.85)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '5996 Sayılı Kanun gereğince kamuoyuna ifşa edilen bu kayıt; halk sağlığı ve güvenilir gıda hakkını koruma amacıyla resmi sistemden paylaşılmıştır.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 9,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline_rounded, size: 11, color: badgeColor),
                    const SizedBox(width: 5),
                    Text(
                      'RESMİ BAKANLIK VERİSİ İLE DOĞRULANMIŞTIR',
                      style: TextStyle(
                        color: badgeColor.withValues(alpha: 0.9),
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // 6. Official Footer Stamp
          Container(
            padding: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.asset(
                        'assets/images/app_logo.png',
                        width: 22,
                        height: 22,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primaryEmerald.withValues(alpha: 0.2),
                          ),
                          child: const Icon(Icons.eco_rounded, color: AppColors.primaryEmerald, size: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    const Text(
                      'OrganicScore',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Tüketmeden Önce Kontrol Edin',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
