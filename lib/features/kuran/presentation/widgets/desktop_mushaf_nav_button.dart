import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Yalnızca masaüstü (Windows, macOS, Linux) işletim sistemlerini doğrular.
bool get isDesktopMushafPlatform {
  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;
}

/// Kur'an-ı Kerim Mushaf ve Mukabele/Hatim ekranlarında masaüstü platformlar
/// için sayfalar arası geçişi sağlayan hover destekli buton.
///
/// Mobil cihazlarda (Android, iOS) tamamen gizlenir.
/// Boşta %30 opaklıkla silik görünür, fare üzerine gelince %100 belirginleşir.
class DesktopMushafNavButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isDark;

  const DesktopMushafNavButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.isDark,
  });

  @override
  State<DesktopMushafNavButton> createState() => _DesktopMushafNavButtonState();
}

class _DesktopMushafNavButtonState extends State<DesktopMushafNavButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    if (!isDesktopMushafPlatform) {
      return const SizedBox.shrink();
    }

    final isDark = widget.isDark;
    final isActive = widget.onPressed != null;

    return MouseRegion(
      cursor: isActive ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Tooltip(
        message: widget.tooltip,
        child: AnimatedScale(
          scale: _isHovered && isActive ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: _isHovered ? 1.0 : 0.30,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onPressed,
                borderRadius: BorderRadius.circular(30),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (isDark ? const Color(0xFF1E2129) : Colors.white)
                        .withValues(alpha: _isHovered ? 0.95 : 0.85),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isHovered
                          ? (isDark
                              ? AppColors.gold400.withValues(alpha: 0.7)
                              : const Color(0xFF2D7D76).withValues(alpha: 0.6))
                          : (isDark
                              ? AppColors.darkBorder
                              : const Color(0xFFE2DDD2)),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark
                              ? (_isHovered ? 0.45 : 0.25)
                              : (_isHovered ? 0.14 : 0.06),
                        ),
                        blurRadius: _isHovered ? 12 : 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.icon,
                    size: 28,
                    color: isActive
                        ? (isDark ? AppColors.gold400 : const Color(0xFF2D7D76))
                        : (isDark ? Colors.white24 : Colors.black26),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
