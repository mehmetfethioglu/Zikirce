import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import '../../services/celebration_service.dart';
import '../../services/haptic_service.dart';
import '../../theme/app_theme_colors.dart';
import 'nur_particles_painter.dart';

class SpiritualCelebrationOverlay extends ConsumerStatefulWidget {
  final Widget child;

  const SpiritualCelebrationOverlay({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<SpiritualCelebrationOverlay> createState() =>
      _SpiritualCelebrationOverlayState();
}

class _SpiritualCelebrationOverlayState
    extends ConsumerState<SpiritualCelebrationOverlay>
    with TickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  late final List<NurParticle> _particles;
  CelebrationEvent? _currentEvent;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _particles = NurParticlesPainter.generateParticles(count: 52);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.75, end: 1.05)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.05, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.15)
            .chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 40,
      ),
    ]).animate(_animController);

    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 30,
      ),
    ]).animate(_animController);

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.12),
      end: const Offset(0.0, -0.08),
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {
            _isVisible = false;
            _currentEvent = null;
          });
          ref.read(celebrationProvider.notifier).clear();
        }
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _triggerCelebration(CelebrationEvent event) {
    if (!mounted) return;
    setState(() {
      _currentEvent = event;
      _isVisible = true;
    });

    _animController.reset();
    _animController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CelebrationEvent?>(celebrationProvider, (prev, next) {
      if (next != null && next != prev) {
        _triggerCelebration(next);
      }
    });

    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,

        // Celebration Layer
        if (_isVisible && _currentEvent != null) ...[
          // For zikir target (non-blocking ambient overlay so taps pass through!)
          if (_currentEvent!.type == CelebrationType.zikirTarget)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: true, // Non-blocking: Allows seamless continuous dhikr tapping!
                child: AnimatedBuilder(
                  animation: _animController,
                  builder: (context, _) {
                    return RepaintBoundary(
                      child: CustomPaint(
                        painter: NurParticlesPainter(
                          progress: _animController.value,
                          particles: _particles,
                          primaryGlowColor: const Color(0xFFEAB308),
                          secondaryGlowColor: colors.accent,
                        ),
                        child: Center(
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: ScaleTransition(
                                scale: _scaleAnimation,
                                child: _buildAmbientZikirBadge(
                                  colors,
                                  isDark,
                                  _currentEvent!,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            )
          else
            // For Daily Goals & Major Milestones (Dismissible soft card overlay)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  _animController.stop();
                  setState(() {
                    _isVisible = false;
                    _currentEvent = null;
                  });
                  ref.read(celebrationProvider.notifier).clear();
                  HapticService.selectionClick();
                },
                child: Container(
                  color: Colors.black.withValues(alpha: 0.45 * _fadeAnimation.value),
                  alignment: Alignment.center,
                  child: AnimatedBuilder(
                    animation: _animController,
                    builder: (context, _) {
                      return RepaintBoundary(
                        child: CustomPaint(
                          painter: NurParticlesPainter(
                            progress: _animController.value,
                            particles: _particles,
                            primaryGlowColor: const Color(0xFFF59E0B),
                            secondaryGlowColor: colors.accent,
                          ),
                          child: Center(
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: ScaleTransition(
                                scale: _scaleAnimation,
                                child: _buildMilestoneCelebrationCard(
                                  colors,
                                  isDark,
                                  _currentEvent!,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }

  /// Ambient Non-Blocking Dhikr Milestone Badge
  Widget _buildAmbientZikirBadge(
    AppThemeColors colors,
    bool isDark,
    CelebrationEvent event,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      margin: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E2622).withValues(alpha: 0.94)
            : Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFEAB308).withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEAB308).withValues(alpha: 0.25),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('✨', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  event.title,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFCA8A04),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text('✨', style: TextStyle(fontSize: 18)),
            ],
          ),
          if (event.subtitle.isNotEmpty && event.subtitle != event.title) ...[
            const SizedBox(height: 4),
            Text(
              event.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
            ),
          ],
          if (event.hadithOrVirtue != null) ...[
            const SizedBox(height: 6),
            Text(
              event.hadithOrVirtue!,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontStyle: FontStyle.italic,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Interactive Milestone Celebration Card for Daily Goals & Achievements
  Widget _buildMilestoneCelebrationCard(
    AppThemeColors colors,
    bool isDark,
    CelebrationEvent event,
  ) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2421) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFFEAB308),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEAB308).withValues(alpha: 0.35),
            blurRadius: 32,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Lottie Asset (Only if non-bird celebratory animation)
          if (event.birdAsset != null &&
              event.birdAsset!.isNotEmpty &&
              !event.birdAsset!.contains('bird')) ...[
            SizedBox(
              width: 120,
              height: 120,
              child: Lottie.asset(
                event.birdAsset!,
                fit: BoxFit.contain,
                repeat: false,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Title
          Text(
            event.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFFB45309),
            ),
          ),
          const SizedBox(height: 4),

          // Subtitle
          Text(
            event.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.primaryText,
            ),
          ),

          if (event.hadithOrVirtue != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                event.hadithOrVirtue!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  fontStyle: FontStyle.italic,
                  color: colors.secondaryText,
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),

          // XP Gained Tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '+${event.xpGained} Manevi Derece',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),
          Text(
            'Kapatmak için dokunun',
            style: TextStyle(
              fontSize: 11,
              color: colors.secondaryTextAlt.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
