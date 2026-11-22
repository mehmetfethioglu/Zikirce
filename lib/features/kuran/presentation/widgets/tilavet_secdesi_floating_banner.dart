import 'package:flutter/material.dart';
import '../../../../core/services/haptic_service.dart';
import '../../data/tilavet_secdesi_data.dart';
import 'tilavet_secdesi_guide_sheet.dart';

class TilavetSecdesiFloatingBanner extends StatefulWidget {
  final TilavetSecdeItem secdeItem;
  final VoidCallback? onDismiss;
  final EdgeInsetsGeometry padding;

  const TilavetSecdesiFloatingBanner({
    super.key,
    required this.secdeItem,
    this.onDismiss,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 6),
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
    if (_animController.isDismissed ||
        _animController.status == AnimationStatus.reverse) {
      return;
    }
    HapticService.selectionClick();
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
    final borderColor =
        isDark ? const Color(0xFFD4AF37) : const Color(0xFF2E7D32);

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: widget.padding,
          child: Container(
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
                color: borderColor,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: Material(
                color: Colors.transparent,
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        key: const Key('tilavet_floating_banner_guide_tap'),
                        onTap: _openGuide,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark
                                      ? const Color(0xFFD4AF37)
                                          .withValues(alpha: 0.2)
                                      : const Color(0xFF2E7D32)
                                          .withValues(alpha: 0.15),
                                  border: Border.all(
                                    color: borderColor,
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
                                        Flexible(
                                          child: Text(
                                            '${widget.secdeItem.no}. Tilâvet Secdesi Âyeti',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: isDark
                                                  ? const Color(0xFFFFDF7A)
                                                  : const Color(0xFF1B5E20),
                                            ),
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
                                            borderRadius:
                                                BorderRadius.circular(6),
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
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      color: borderColor.withValues(alpha: 0.28),
                    ),
                    Semantics(
                      button: true,
                      label: 'Kapat',
                      child: Tooltip(
                        message: 'Kapat',
                        child: InkWell(
                          key: const Key(
                              'tilavet_floating_banner_close_button'),
                          onTap: _handleDismiss,
                          borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(17),
                          ),
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: Center(
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.1)
                                      : const Color(0xFF2E7D32)
                                          .withValues(alpha: 0.12),
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: isDark
                                      ? Colors.white70
                                      : const Color(0xFF1B5E20),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
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
