import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/services/haptic_service.dart';

enum SessionPinMode { verify, create }

class SessionPinDialog extends StatefulWidget {
  final SessionPinMode mode;
  final String title;
  final String? subtitle;
  final bool Function(String pin)? onVerify;

  const SessionPinDialog({
    super.key,
    this.mode = SessionPinMode.verify,
    required this.title,
    this.subtitle,
    this.onVerify,
  });

  /// PIN Doğrulama için gösterir
  static Future<bool> showVerify(
    BuildContext context, {
    required String title,
    String? subtitle,
    required bool Function(String pin) onVerify,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SessionPinDialog(
        mode: SessionPinMode.verify,
        title: title,
        subtitle: subtitle,
        onVerify: onVerify,
      ),
    );
    return result ?? false;
  }

  /// Yeni PIN Oluşturma için gösterir
  static Future<String?> showCreate(
    BuildContext context, {
    String title = 'Profil PIN Kodu Belirle',
    String? subtitle,
  }) async {
    return await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => SessionPinDialog(
        mode: SessionPinMode.create,
        title: title,
        subtitle: subtitle,
      ),
    );
  }

  @override
  State<SessionPinDialog> createState() => _SessionPinDialogState();
}

class _SessionPinDialogState extends State<SessionPinDialog> with SingleTickerProviderStateMixin {
  String _enteredPin = '';
  String _firstEnteredPin = '';
  bool _isConfirming = false;
  String? _errorMessage;
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -12.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 12.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onKeyPress(String val) {
    if (_enteredPin.length >= 4) return;
    HapticService.lightImpact();

    setState(() {
      _enteredPin += val;
      _errorMessage = null;
    });

    if (_enteredPin.length == 4) {
      _handleSubmit();
    }
  }

  void _onBackspace() {
    if (_enteredPin.isEmpty) return;
    HapticService.lightImpact();
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _errorMessage = null;
    });
  }

  Future<void> _handleSubmit() async {
    if (widget.mode == SessionPinMode.verify) {
      final isValid = widget.onVerify?.call(_enteredPin) ?? false;
      if (isValid) {
        HapticService.lightImpact();
        Navigator.of(context).pop(true);
      } else {
        HapticService.error();
        _shakeController.forward(from: 0.0);
        setState(() {
          _enteredPin = '';
          _errorMessage = 'Hatalı PIN kodu! Lütfen tekrar deneyin.';
        });
      }
    } else {
      // Create mode
      if (!_isConfirming) {
        _firstEnteredPin = _enteredPin;
        setState(() {
          _enteredPin = '';
          _isConfirming = true;
          _errorMessage = null;
        });
      } else {
        if (_enteredPin == _firstEnteredPin) {
          HapticService.lightImpact();
          Navigator.of(context).pop(_enteredPin);
        } else {
          HapticService.error();
          _shakeController.forward(from: 0.0);
          setState(() {
            _enteredPin = '';
            _firstEnteredPin = '';
            _isConfirming = false;
            _errorMessage = 'PIN kodları eşleşmedi! Baştan girin.';
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = colors.statusBrightness == Brightness.light;

    final currentTitle = widget.mode == SessionPinMode.create
        ? (_isConfirming ? 'PIN Kodunu Onaylayın' : widget.title)
        : widget.title;

    final currentSubtitle = widget.mode == SessionPinMode.create
        ? (_isConfirming ? 'Lütfen belirlediğiniz 4 haneli PIN kodunu tekrar girin' : (widget.subtitle ?? '4 haneli güvenlik PIN kodu girin'))
        : (widget.subtitle ?? 'Bu profile erişmek için PIN kodunuzu girin');

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: AnimatedBuilder(
        animation: _shakeAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(_shakeAnimation.value, 0),
            child: child,
          );
        },
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colors.cardBackground,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: colors.borderStroke, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.12),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Header
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_rounded, color: colors.accent, size: 28),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                currentTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colors.primaryText,
                ),
              ),
              const SizedBox(height: 6),

              // Subtitle
              Text(
                currentSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: colors.secondaryTextAlt,
                ),
              ),
              const SizedBox(height: 24),

              // 4 PIN Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final isFilled = index < _enteredPin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: isFilled ? 18 : 14,
                    height: isFilled ? 18 : 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFilled ? colors.accent : Colors.transparent,
                      border: Border.all(
                        color: isFilled ? colors.accent : colors.borderStroke,
                        width: 2,
                      ),
                      boxShadow: isFilled
                          ? [
                              BoxShadow(
                                color: colors.accent.withValues(alpha: 0.4),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                  );
                }),
              ),

              // Error Message
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else
                const SizedBox(height: 20),

              // Numpad Keypad (1-9, cancel, 0, backspace)
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                childAspectRatio: 1.4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: [
                  for (int i = 1; i <= 9; i++) _buildKeyButton('$i', colors),
                  _buildActionButton(
                    icon: Icons.close_rounded,
                    label: 'İptal',
                    onTap: () => Navigator.of(context).pop(null),
                    colors: colors,
                  ),
                  _buildKeyButton('0', colors),
                  _buildActionButton(
                    icon: Icons.backspace_outlined,
                    label: '',
                    onTap: _onBackspace,
                    colors: colors,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeyButton(String text, AppThemeColors colors) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onKeyPress(text),
        borderRadius: BorderRadius.circular(18),
        splashColor: colors.accent.withValues(alpha: 0.2),
        highlightColor: colors.accent.withValues(alpha: 0.1),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.primaryText.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.borderStroke.withValues(alpha: 0.6), width: 1),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: colors.primaryText,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required AppThemeColors colors,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: colors.accent.withValues(alpha: 0.15),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
          ),
          child: label.isNotEmpty
              ? Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.secondaryTextAlt,
                  ),
                )
              : Icon(icon, size: 22, color: colors.secondaryTextAlt),
        ),
      ),
    );
  }
}
