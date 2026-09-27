import 'package:flutter/material.dart';
import '../../../../core/services/haptic_service.dart';
import '../../data/tilavet_secdesi_data.dart';
import 'tilavet_secdesi_guide_sheet.dart';

class TilavetSecdesiFloatingBanner extends StatefulWidget {
  final TilavetSecdeItem secdeItem;
  final VoidCallback? onDismiss;

  const TilavetSecdesiFloatingBanner({
    super.key,
    required this.secdeItem,
    this.onDismiss,
  });

  @override
  State<TilavetSecdesiFloatingBanner> createState() =>
      _TilavetSecdesiFloatingBannerState();
}

class _TilavetSecdesiFloatingBannerState
    extends State<TilavetSecdesiFloatingBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    ));

    _animController.forward();
    HapticService.selectionClick();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleDismiss() async {
    await _animController.reverse();
    if (mounted) {
      widget.onDismiss?.call();
    }
  }

  void _openGuide() {
    HapticService.tapClick();
    TilavetSecdesiGuideSheet.show(
      context,
      initialSecdeItem: widget.secdeItem,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _openGuide,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  gradient: isDark
                      ? const LinearGradient(
                          colors: [Color(0xFF1B382F), Color(0xFF132822)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : const LinearGradient(
                          colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFFD4AF37)
                        : const Color(0xFF2E7D32),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? const Color(0xFFD4AF37).withValues(alpha: 0.2)
                            : const Color(0xFF2E7D32).withValues(alpha: 0.15),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFFD4AF37)
                              : const Color(0xFF2E7D32),
                          width: 1,
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          '🕌',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${widget.secdeItem.no}. Tilâvet Secdesi Âyeti',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? const Color(0xFFFFDF7A)
                                      : const Color(0xFF1B5E20),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFFD4AF37)
                                          .withValues(alpha: 0.25)
                                      : const Color(0xFF2E7D32)
                                          .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Vâcip',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF1B5E20),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.secdeItem.sureName} Sûresi, ${widget.secdeItem.ayetId}. Âyet • Dokun ve Rehberi Gör',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? const Color(0xFFD6D3CD)
                                  : const Color(0xFF2E7D32),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Kapat',
                      onPressed: _handleDismiss,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
