import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';

/// Orijinal bozuk/sıkışık PDF görünümü ile Tahrir Akıllı Metin Akışı (Smart Reflow)
/// arasında parmakla sağa-sola kaydırılabilen canlı "X-Ray Dönüşüm Perdesi" widget'ı.
class XRaySplitViewWidget extends StatefulWidget {
  final Widget originalPdfView;
  final Widget smartReflowView;
  final VoidCallback onExitXRay;

  const XRaySplitViewWidget({
    super.key,
    required this.originalPdfView,
    required this.smartReflowView,
    required this.onExitXRay,
  });

  @override
  State<XRaySplitViewWidget> createState() => _XRaySplitViewWidgetState();
}

class _XRaySplitViewWidgetState extends State<XRaySplitViewWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _introSweepController;
  double _splitRatio = 0.44;
  bool _userInteracted = false;

  @override
  void initState() {
    super.initState();
    _introSweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    // Açılışta PDF'ten Reflow'a doğru zarif bir X-Ray tarama salınımı göster
    _introSweepController.addListener(() {
      if (!_userInteracted && mounted) {
        final t = Curves.easeInOutCubic.transform(_introSweepController.value);
        setState(() {
          _splitRatio = 0.72 - (t * 0.30); // 0.72 -> 0.42
        });
      }
    });
    _introSweepController.forward();
  }

  @override
  void dispose() {
    _introSweepController.dispose();
    super.dispose();
  }

  void _updateSplit(double localDx, double maxWidth) {
    if (maxWidth <= 0) return;
    _userInteracted = true;
    setState(() {
      _splitRatio = (localDx / maxWidth).clamp(0.08, 0.92);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final dividerX = width * _splitRatio;

        return Stack(
          children: [
            // 1. Katman (Alt/Sağ): Tahrir Akıllı Metin Akışı (Smart Reflow)
            Positioned.fill(
              child: widget.smartReflowView,
            ),

            // 2. Katman (Üst/Sol): Orijinal PDF Mizanpajı (Sol tarafta kırpılmış)
            Positioned.fill(
              child: ClipRect(
                clipper: _HorizontalSplitClipper(splitX: dividerX),
                child: widget.originalPdfView,
              ),
            ),

            // 3. Sol & Sağ Durum Rozetleri (Orijinal PDF vs. Tahrir Akışı)
            Positioned(
              left: 12,
              top: 76,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _splitRatio > 0.22 ? 1.0 : 0.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.24),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.picture_as_pdf_outlined,
                          size: 13,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Ham PDF',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            Positioned(
              right: 12,
              top: 76,
              child: GestureDetector(
                onTap: widget.onExitXRay,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _splitRatio < 0.78 ? 1.0 : 0.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.terracotta, AppColors.amberGold],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.amberGold.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          size: 13,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Tahrir Akışı (Tam Ekran)',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 4. Altın Işık Perdesi Çizgisi ve Sürükleme Tutamacı (X-Ray Laser Line)
            Positioned(
              left: (dividerX - 24).clamp(0.0, width - 48),
              top: 0,
              bottom: 0,
              width: 48,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragUpdate: (details) {
                  final box = context.findRenderObject() as RenderBox?;
                  if (box != null) {
                    final localPos = box.globalToLocal(details.globalPosition);
                    _updateSplit(localPos.dx, width);
                  }
                },
                onDoubleTap: widget.onExitXRay,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Dikey Altın Lazer Çizgisi
                    Container(
                      width: 3,
                      height: height,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            AppColors.amberGold,
                            AppColors.terracotta,
                            AppColors.amberGold,
                            Colors.transparent,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.amberGold.withValues(alpha: 0.65),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),

                    // Orta Sürükleme Mührü (Handle)
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.amberGold,
                          width: 2.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.28),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: AppColors.amberGold.withValues(alpha: 0.35),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chevron_left,
                            size: 16,
                            color: AppColors.terracotta,
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: AppColors.amberGold,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HorizontalSplitClipper extends CustomClipper<Rect> {
  final double splitX;

  const _HorizontalSplitClipper({required this.splitX});

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, splitX.clamp(0.0, size.width), size.height);
  }

  @override
  bool shouldReclip(covariant _HorizontalSplitClipper oldClipper) {
    return oldClipper.splitX != splitX;
  }
}
