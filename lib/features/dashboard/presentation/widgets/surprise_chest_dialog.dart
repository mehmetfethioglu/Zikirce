import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/services/sound_pool_service.dart';
import '../../../gamification/models/surprise_chest_reward.dart';

class SurpriseChestDialog extends StatefulWidget {
  final SurpriseChestReward reward;
  final VoidCallback? onClaimed;

  const SurpriseChestDialog({
    super.key,
    required this.reward,
    this.onClaimed,
  });

  static Future<void> show(
    BuildContext context, {
    required SurpriseChestReward reward,
    VoidCallback? onClaimed,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'SurpriseChest',
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => SurpriseChestDialog(
        reward: reward,
        onClaimed: onClaimed,
      ),
      transitionBuilder: (context, anim, _, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
    );
  }

  @override
  State<SurpriseChestDialog> createState() => _SurpriseChestDialogState();
}

class _SurpriseChestDialogState extends State<SurpriseChestDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  bool _isOpened = false;
  String _chestEmoji = '📦';
  double _chestScale = 1.0;
  double _glowScale = 1.0;
  double _glowOpacity = 0.15;
  bool _showReward = false;
  String _promptText = 'Açmak için sandığa dokunun!';

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _handleChestTap() async {
    if (_isOpened) return;
    setState(() {
      _isOpened = true;
      _promptText = 'Sandık Açılıyor...';
    });

    HapticService.countTap();

    // 1. Shake animation (4 cycles)
    for (int i = 0; i < 4; i++) {
      if (!mounted) return;
      await _shakeController.forward(from: 0.0);
    }

    if (!mounted) return;

    // 2. Chest opening transition
    setState(() {
      _chestEmoji = '🔓';
    });

    await Future.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;

    setState(() {
      _chestEmoji = '🎁';
      _chestScale = 1.25;
      _glowScale = 1.4;
      _glowOpacity = 0.45;
      _showReward = true;
      _promptText = widget.reward.message;
    });

    HapticService.targetReached();
    SoundPoolService.playChirp(type: 'bulbul');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 330,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151F32) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Title Header
              const Text(
                '🎉 ALTIN GÜN SÜRPRİZİ! 🎉',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFEAB308),
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Sürpriz Sandık',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: colors.primaryText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // 2. Chest & Glow Animation Area
              GestureDetector(
                onTap: _handleChestTap,
                child: SizedBox(
                  width: 150,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Glow Background Aura
                      AnimatedScale(
                        scale: _glowScale,
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOutBack,
                        child: AnimatedOpacity(
                          opacity: _glowOpacity,
                          duration: const Duration(milliseconds: 350),
                          child: Container(
                            width: 130,
                            height: 130,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFFFD700),
                            ),
                          ),
                        ),
                      ),

                      // Chest Emoji with Shake Transition
                      AnimatedBuilder(
                        animation: _shakeController,
                        builder: (context, child) {
                          final offset = _isOpened && !_showReward
                              ? (12 * (_shakeController.value < 0.5 ? 1 : -1) * (1 - _shakeController.value))
                              : 0.0;
                          return Transform.translate(
                            offset: Offset(offset, 0),
                            child: AnimatedScale(
                              scale: _chestScale,
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutBack,
                              child: Text(
                                _chestEmoji,
                                style: const TextStyle(fontSize: 84),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 3. Reward Display Card (revealed after open)
              AnimatedOpacity(
                opacity: _showReward ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 350),
                child: _showReward ? _buildRewardCard(isDark) : const SizedBox(height: 80),
              ),

              const SizedBox(height: 12),

              // 4. Prompt Message
              Text(
                _promptText,
                style: TextStyle(
                  fontSize: 12.5,
                  fontStyle: _showReward ? FontStyle.normal : FontStyle.italic,
                  color: _showReward ? colors.primaryText : colors.secondaryTextAlt,
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 18),

              // 5. Action Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _showReward
                      ? () {
                          HapticService.selectionClick();
                          Navigator.of(context).pop();
                          widget.onClaimed?.call();
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEAB308),
                    disabledBackgroundColor: const Color(0xFFEAB308).withValues(alpha: 0.3),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white60,
                    elevation: _showReward ? 4 : 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    widget.reward.isPendingYatsi
                        ? 'Tamam (Yatsı Namazında Aktarılacak)'
                        : 'Ödülü Al ve Devam Et',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRewardCard(bool isDark) {
    switch (widget.reward.type) {
      case ChestRewardType.gold:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2510) : const Color(0xFFFEF08A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEAB308), width: 1.5),
          ),
          child: Column(
            children: [
              const Text('🪙', style: TextStyle(fontSize: 32)),
              Text(
                '+${widget.reward.goldAmount}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFCA8A04),
                ),
              ),
              Text(
                'Altın Kazandınız!',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFFFACC15) : const Color(0xFF854D0E),
                ),
              ),
              if (widget.reward.isPendingYatsi) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.black38 : Colors.white70),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🌙', style: TextStyle(fontSize: 11)),
                      const SizedBox(width: 4),
                      Text(
                        'Yatsı namazı kılındığında hesaba aktarılacak',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFFFDE047) : const Color(0xFF78350F),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );

      case ChestRewardType.diamond:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF102A35) : const Color(0xFFCFFAFE),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF06B6D4), width: 1.5),
          ),
          child: Column(
            children: [
              const Text('💎', style: TextStyle(fontSize: 32)),
              Text(
                '+${widget.reward.diamondAmount}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0891B2),
                ),
              ),
              Text(
                'Elmas Kazandınız!',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFF22D3EE) : const Color(0xFF155E75),
                ),
              ),
            ],
          ),
        );

      case ChestRewardType.bird:
        final birdFile = widget.reward.birdFileName;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0C4A6E) : const Color(0xFFE0F2FE),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF0284C7), width: 1.5),
          ),
          child: Column(
            children: [
              if (birdFile != null && birdFile.isNotEmpty)
                SizedBox(
                  width: 50,
                  height: 50,
                  child: Lottie.asset(
                    birdFile,
                    errorBuilder: (_, __, ___) => Text(
                      widget.reward.birdBadge ?? '🕊️',
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                )
              else
                Text(widget.reward.birdBadge ?? '🕊️', style: const TextStyle(fontSize: 32)),
              const SizedBox(height: 2),
              Text(
                widget.reward.birdName ?? 'Mertebe Kuşu',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0284C7),
                ),
              ),
              Text(
                'Yeni Kuş Kilidi Açıldı! 🎉',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1),
                ),
              ),
            ],
          ),
        );

      case ChestRewardType.legendaryBonus:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF312E1B) : const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF59E0B), width: 2),
          ),
          child: Column(
            children: [
              const Text(
                '👑 EFSANEVİ USTA BONUSU',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD97706),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      const Text('🪙', style: TextStyle(fontSize: 24)),
                      Text(
                        '+${widget.reward.goldAmount}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFCA8A04)),
                      ),
                      const Text('Altın', style: TextStyle(fontSize: 10, color: Color(0xFF854D0E))),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('💎', style: TextStyle(fontSize: 24)),
                      Text(
                        '+${widget.reward.diamondAmount}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0891B2)),
                      ),
                      const Text('Elmas', style: TextStyle(fontSize: 10, color: Color(0xFF155E75))),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
    }
  }
}
