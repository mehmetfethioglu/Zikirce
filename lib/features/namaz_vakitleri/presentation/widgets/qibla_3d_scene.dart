import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../domain/qibla_math.dart';
import '../../domain/qibla_models.dart';
import 'qibla_3d_painter.dart';

/// 120 FPS animasyonlu 3B Kıble sahnesi sarmalayıcısı.
///
/// Nefes döngüsünü, İftitah Tekbiri -> Kıyam koreografisini, merkezlenmiş
/// anıtsal yakınlaşmayı ve kilitlenme kararlılığını yönetir.
class Qibla3DScene extends StatefulWidget {
  final QiblaState state;
  final bool isTurkish;
  final ValueChanged<double>? onManualRotate;
  final VoidCallback? onTapAligned;

  const Qibla3DScene({
    super.key,
    required this.state,
    required this.isTurkish,
    this.onManualRotate,
    this.onTapAligned,
  });

  @override
  State<Qibla3DScene> createState() => _Qibla3DSceneState();
}

class _Qibla3DSceneState extends State<Qibla3DScene>
    with TickerProviderStateMixin {
  late final AnimationController _breathController;
  late final AnimationController _takbirController;
  late final AnimationController _cameraOrbitController;
  late final AnimationController _lockSnapController;
  late final AnimationController _headingController;

  late double _fromHeadingDeg;
  late double _toHeadingDeg;
  double _currentDisplayHeadingDeg = 0.0;
  bool _disableAnimations = false;

  @override
  void initState() {
    super.initState();
    _fromHeadingDeg = widget.state.headingDeg;
    _toHeadingDeg = widget.state.headingDeg;
    _currentDisplayHeadingDeg = widget.state.headingDeg;

    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    )..repeat();

    _takbirController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    );

    _cameraOrbitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    _lockSnapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );

    _headingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
    )..addListener(() {
        final t = Curves.easeOutCubic.transform(_headingController.value);
        final delta =
            QiblaMath.shortestAngleDelta(_fromHeadingDeg, _toHeadingDeg);
        _currentDisplayHeadingDeg =
            QiblaMath.normalizeAngleDeg(_fromHeadingDeg + delta * t);
      });

    _syncPhaseAnimations(widget.state.phase, initial: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disable != _disableAnimations) {
      _disableAnimations = disable;
      if (_disableAnimations) {
        _breathController.stop();
        _breathController.value = 0.0;
      } else if (!_breathController.isAnimating) {
        _breathController.repeat();
      }
      _syncPhaseAnimations(widget.state.phase, initial: true);
    }
  }

  @override
  void didUpdateWidget(covariant Qibla3DScene oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.state.headingDeg != widget.state.headingDeg) {
      if (widget.state.isInteractivePreview || _disableAnimations) {
        // Sürüklemede veya hareket azaltma modunda gecikmesiz yanıt ver.
        _headingController.stop();
        _fromHeadingDeg = widget.state.headingDeg;
        _toHeadingDeg = widget.state.headingDeg;
        _currentDisplayHeadingDeg = widget.state.headingDeg;
      } else {
        _fromHeadingDeg = _currentDisplayHeadingDeg;
        _toHeadingDeg = widget.state.headingDeg;
        _headingController.forward(from: 0.0);
      }
    }

    if (oldWidget.state.takbirReplayTick != widget.state.takbirReplayTick) {
      if (_disableAnimations) {
        _takbirController.value = 0.45;
      } else {
        _takbirController.forward(from: 0.0);
      }
    }

    if (oldWidget.state.phase != widget.state.phase) {
      _syncPhaseAnimations(widget.state.phase, initial: false);
    }
  }

  void _syncPhaseAnimations(
    QiblaAlignmentPhase phase, {
    required bool initial,
  }) {
    final isLockedFamily = phase == QiblaAlignmentPhase.locked ||
        phase == QiblaAlignmentPhase.takbir ||
        phase == QiblaAlignmentPhase.qiyam;
    final isTakbirOrQiyam =
        phase == QiblaAlignmentPhase.takbir || phase == QiblaAlignmentPhase.qiyam;

    if (_disableAnimations) {
      _lockSnapController.value = isLockedFamily ? 1.0 : 0.0;
      _cameraOrbitController.value = isTakbirOrQiyam ? 1.0 : 0.0;
      if (phase == QiblaAlignmentPhase.takbir) {
        _takbirController.value = 0.45;
      } else if (phase == QiblaAlignmentPhase.qiyam) {
        _takbirController.value = 1.0;
      } else {
        _takbirController.value = 0.0;
      }
      return;
    }

    if (isLockedFamily) {
      if (initial) {
        _lockSnapController.value = 1.0;
      } else if (_lockSnapController.value < 1.0) {
        _lockSnapController.forward();
      }
    } else if (_lockSnapController.value > 0.0) {
      _lockSnapController.reverse();
    }

    if (isTakbirOrQiyam) {
      if (initial && phase == QiblaAlignmentPhase.qiyam) {
        _takbirController.value = 1.0;
        _cameraOrbitController.value = 1.0;
      } else {
        if (_takbirController.value < 1.0) {
          _takbirController.forward();
        }
        if (_cameraOrbitController.value < 1.0) {
          _cameraOrbitController.forward();
        }
      }
    } else {
      if (_takbirController.value > 0.0) {
        _takbirController.reverse();
      }
      if (_cameraOrbitController.value > 0.0) {
        _cameraOrbitController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _breathController.dispose();
    _takbirController.dispose();
    _cameraOrbitController.dispose();
    _lockSnapController.dispose();
    _headingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = colors.statusBrightness == Brightness.light;
    const goldColor = Color(0xFFD4A574);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.state.phase == QiblaAlignmentPhase.qiyam
          ? widget.onTapAligned
          : null,
      onHorizontalDragUpdate: widget.state.isInteractivePreview &&
              widget.onManualRotate != null
          ? (details) => widget.onManualRotate!(-details.delta.dx * 0.55)
          : null,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: Listenable.merge(<Listenable>[
            _breathController,
            _takbirController,
            _cameraOrbitController,
            _lockSnapController,
            _headingController,
          ]),
          builder: (context, _) {
            final orbitT = Curves.easeInOutCubic.transform(
              _cameraOrbitController.value,
            );
            final lockSnapT = Curves.easeOutCubic.transform(
              _lockSnapController.value,
            );
            return CustomPaint(
              isComplex: true,
              willChange: true,
              painter: Qibla3DPainter(
                displayHeadingDeg: _currentDisplayHeadingDeg,
                qiblaBearingDeg: widget.state.qiblaBearingDeg,
                sunAzimuthDeg: widget.state.sunAzimuthDeg,
                isSunVisible: widget.state.isSunVisible,
                tiltDeg: widget.state.tiltDeg,
                pitchDeg: widget.state.pitchDeg,
                rollDeg: widget.state.rollDeg,
                isPhoneFlat: widget.state.isPhoneFlat,
                isInteractivePreview: widget.state.isInteractivePreview,
                phase: widget.state.phase,
                figureMode: widget.state.figureMode,
                breathPhase: _disableAnimations ? 0.0 : _breathController.value,
                takbirProgress: _takbirController.value,
                cameraOrbitProgress: orbitT,
                lockSnapProgress: lockSnapT,
                isTurkish: widget.isTurkish,
                isDark: isDark,
                accentColor: colors.accent,
                goldColor: goldColor,
                cardBackground: colors.cardBackground,
                primaryText: colors.primaryText,
                secondaryText: colors.secondaryTextAlt,
              ),
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    );
  }
}
