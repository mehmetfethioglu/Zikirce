import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/qibla_math.dart';
import '../../domain/qibla_models.dart';

class _Vec3 {
  final double x;
  final double y;
  final double z;

  const _Vec3(this.x, this.y, this.z);

  _Vec3 operator +(_Vec3 o) => _Vec3(x + o.x, y + o.y, z + o.z);
  _Vec3 operator -(_Vec3 o) => _Vec3(x - o.x, y - o.y, z - o.z);
  _Vec3 operator *(double s) => _Vec3(x * s, y * s, z * s);

  double dot(_Vec3 o) => x * o.x + y * o.y + z * o.z;

  _Vec3 cross(_Vec3 o) => _Vec3(
        y * o.z - z * o.y,
        z * o.x - x * o.z,
        x * o.y - y * o.x,
      );

  double get length => math.sqrt(x * x + y * y + z * z);

  _Vec3 normalized() {
    final len = length;
    if (len < 1e-6) return const _Vec3(0, 0, 1);
    return _Vec3(x / len, y / len, z / len);
  }
}

class _ProjectedPoint {
  final Offset offset;
  final double depth;

  const _ProjectedPoint(this.offset, this.depth);
}

class _Face3D {
  final List<Offset> points;
  final double depth;
  final Color fill;
  final Color? stroke;
  final double strokeWidth;

  const _Face3D({
    required this.points,
    required this.depth,
    required this.fill,
    this.stroke,
    this.strokeWidth = 0.55,
  });
}

class _LoftRing {
  final double z;
  final double rx;
  final double ry;
  final double pleatAmp;
  final Color bandColor;

  const _LoftRing({
    required this.z,
    required this.rx,
    required this.ry,
    required this.bandColor,
    this.pleatAmp = 0.0,
  });
}

/// Saf Flutter 3B projeksiyon motoru: pusula zemini, anıtsal Kâbe külliyesi,
/// dikişsiz katmanlı figür ve su terazisi senaryosunu çizer.
class Qibla3DPainter extends CustomPainter {
  /// Dünya birimi cinsinden orantı sabitleri (Kâbe her zaman figürden yüksek/anıtsaldır).
  static const double kaabaWorldHeight = 0.786;
  static const double characterWorldHeight = 0.680;

  final double displayHeadingDeg;
  final double qiblaBearingDeg;
  final double sunAzimuthDeg;
  final bool isSunVisible;
  final double tiltDeg;
  final double pitchDeg;
  final double rollDeg;
  final bool isPhoneFlat;
  final bool isInteractivePreview;
  final QiblaAlignmentPhase phase;
  final QiblaFigureMode figureMode;
  final double breathPhase;
  final double takbirProgress;
  final double cameraOrbitProgress;
  final double lockSnapProgress;
  final bool isTurkish;
  final bool isDark;
  final Color accentColor;
  final Color goldColor;
  final Color cardBackground;
  final Color primaryText;
  final Color secondaryText;

  Qibla3DPainter({
    required this.displayHeadingDeg,
    required this.qiblaBearingDeg,
    required this.sunAzimuthDeg,
    required this.isSunVisible,
    required this.tiltDeg,
    required this.pitchDeg,
    required this.rollDeg,
    required this.isPhoneFlat,
    required this.isInteractivePreview,
    required this.phase,
    required this.figureMode,
    required this.breathPhase,
    required this.takbirProgress,
    required this.cameraOrbitProgress,
    this.lockSnapProgress = 0.0,
    required this.isTurkish,
    required this.isDark,
    required this.accentColor,
    required this.goldColor,
    required this.cardBackground,
    required this.primaryText,
    required this.secondaryText,
  });

  static const double _degToRad = math.pi / 180.0;
  static const double _ringRadius = 1.66;
  static const double _kaabaRadius = 1.50;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final rawDeltaDeg = QiblaMath.shortestAngleDelta(
      displayHeadingDeg,
      qiblaBearingDeg,
    );
    // Kilitlenme sonrası görsel manyetik tutunma: ±9° penceresinde Kâbe sıfır sapmayla merkezde sabit kalır.
    final snap = lockSnapProgress.clamp(0.0, 1.0);
    final visualDeltaDeg = rawDeltaDeg * (1.0 - snap);
    final visualHeadingDeg = QiblaMath.normalizeAngleDeg(
      qiblaBearingDeg - visualDeltaDeg,
    );
    final absDelta = visualDeltaDeg.abs();
    final relKaabaRad = visualDeltaDeg * _degToRad;
    final alignedGlow = (1.0 - (absDelta / 25.0).clamp(0.0, 1.0)) *
        (isPhoneFlat || isInteractivePreview ? 1.0 : 0.35);
    final isLockedVisual = phase == QiblaAlignmentPhase.locked ||
        phase == QiblaAlignmentPhase.takbir ||
        phase == QiblaAlignmentPhase.qiyam;

    // Tam merkezli anıtsal yakınlaşma (yaw=0): kıble bulununca yatay kayma olmaz.
    const cameraYawRad = 0.0;
    final cameraPitchRad = (37.0 - 14.0 * cameraOrbitProgress) * _degToRad;
    final cameraTarget = _Vec3(
      0.0,
      0.16 + 0.12 * cameraOrbitProgress,
      0.30 + 0.06 * cameraOrbitProgress,
    );
    final cameraDist = 4.75 - 0.70 * cameraOrbitProgress;
    final focalLength = math.min(size.width, size.height) * 0.98;
    final center = Offset(
      size.width * 0.5,
      size.height * (0.53 + 0.01 * cameraOrbitProgress),
    );

    final cosYaw = math.cos(cameraYawRad);
    final sinYaw = math.sin(cameraYawRad);
    final cosPitch = math.cos(cameraPitchRad);
    final sinPitch = math.sin(cameraPitchRad);

    _ProjectedPoint project(_Vec3 world, {double depthBias = 0.0}) {
      final dx = world.x - cameraTarget.x;
      final dy = world.y - cameraTarget.y;
      final dz = world.z - cameraTarget.z;

      final x1 = dx * cosYaw - dy * sinYaw;
      final y1 = dx * sinYaw + dy * cosYaw;
      final z1 = dz;

      final y2 = y1 * cosPitch - z1 * sinPitch;
      final z2 = y1 * sinPitch + z1 * cosPitch;

      final depth = math.max(0.45, cameraDist + y2);
      final scale = focalLength / depth;

      return _ProjectedPoint(
        Offset(center.dx + x1 * scale, center.dy - z2 * scale),
        depth + depthBias,
      );
    }

    // Sıcak kamera tarafı Harem anahtar ışığı (-Y yönünden aydınlatma, sıfır arkadan kararma)
    final lightBlend = (absDelta / 12.0).clamp(0.0, 1.0);
    final lightDir = _Vec3(
      0.36 + math.sin(relKaabaRad) * 0.20 * lightBlend,
      -0.58,
      0.74,
    ).normalized();

    // 1. Arka plan Harem ufuk halesi
    _paintAtmosphereBackdrop(
      canvas,
      size,
      center,
      project: project,
      relKaabaRad: relKaabaRad,
      alignedGlow: alignedGlow,
      isLockedVisual: isLockedVisual,
    );

    // 2. Zemin 3B Selçuklu Pusula Halkası, Yönler, Güneş İşareti ve Rehber Yay
    _paintGroundCompassRing(
      canvas,
      project: project,
      visualHeadingDeg: visualHeadingDeg,
      deltaDeg: visualDeltaDeg,
      alignedGlow: alignedGlow,
      isLockedVisual: isLockedVisual,
    );

    // 3. Yaklaşma / Kilitlenme Nur Koridoru (Seccade mihrabından Kâbe avlusuna)
    if (absDelta <= QiblaMath.approachingThresholdDeg) {
      _paintNurCorridor(
        canvas,
        project: project,
        relKaabaRad: relKaabaRad,
        intensity: alignedGlow,
        isLockedVisual: isLockedVisual,
      );
    }

    // 4. Tekbir zemin dalga halkası (avluda genişleyen altın dalga)
    if (takbirProgress > 0.05 && takbirProgress < 0.92) {
      _paintTakbirGroundRipple(
        canvas,
        project: project,
        takbirProgress: takbirProgress,
      );
    }

    // 5. Katı 3B Yüzeyler (Seccade + Kâbe Külliyesi + Figür)
    final faces = <_Face3D>[];

    _buildPrayerRugFaces(
      faces,
      project: project,
      lightDir: lightDir,
      alignedGlow: alignedGlow,
      isLockedVisual: isLockedVisual,
    );

    _buildKaabaSanctuaryFaces(
      faces,
      project: project,
      lightDir: lightDir,
      relKaabaRad: relKaabaRad,
      alignedGlow: alignedGlow,
      isLockedVisual: isLockedVisual,
    );

    if (figureMode != QiblaFigureMode.prayerRugOnly) {
      _buildCharacterFaces(
        faces,
        project: project,
        lightDir: lightDir,
        deltaDeg: visualDeltaDeg,
      );
    } else {
      _buildMihrabArchFaces(
        faces,
        project: project,
        lightDir: lightDir,
        alignedGlow: alignedGlow,
      );
    }

    faces.sort((a, b) => b.depth.compareTo(a.depth));
    final fillPaint = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    for (final face in faces) {
      if (face.points.length < 3) continue;
      final path = Path()..addPolygon(face.points, true);
      fillPaint.color = face.fill;
      canvas.drawPath(path, fillPaint);
      if (face.stroke != null) {
        strokePaint
          ..color = face.stroke!
          ..strokeWidth = face.strokeWidth;
        canvas.drawPath(path, strokePaint);
      }
    }

    // 6. Kâbe Nur Sütunu & Tekbir Halesi ("Allâhu Ekber")
    _paintKaabaBeacon(
      canvas,
      project: project,
      relKaabaRad: relKaabaRad,
      alignedGlow: alignedGlow,
      isLockedVisual: isLockedVisual,
    );

    if (takbirProgress > 0.08) {
      _paintTakbirAuraAndCalligraphy(
        canvas,
        project: project,
        relKaabaRad: relKaabaRad,
        takbirProgress: takbirProgress,
      );
    }

    // 7. Telefon Düz Tutma Su Terazisi (eğim fazlaysa ön katmanda net uyarı)
    if (!isInteractivePreview && !isPhoneFlat) {
      _paintSpiritLevelOverlay(
        canvas,
        project: project,
        pitchDeg: pitchDeg,
        rollDeg: rollDeg,
      );
    }
  }

  void _paintAtmosphereBackdrop(
    Canvas canvas,
    Size size,
    Offset center, {
    required _ProjectedPoint Function(_Vec3, {double depthBias}) project,
    required double relKaabaRad,
    required double alignedGlow,
    required bool isLockedVisual,
  }) {
    final radius = size.longestSide * 0.65;
    final glowColor = isLockedVisual
        ? goldColor.withValues(alpha: isDark ? 0.22 : 0.16)
        : accentColor.withValues(alpha: 0.07 + alignedGlow * 0.12);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.9,
          colors: <Color>[
            glowColor,
            accentColor.withValues(alpha: 0.025),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    // Kâbe arkasında sıcak Mescid-i Haram ufuk parıltısı
    if (alignedGlow > 0.08) {
      final kx = _kaabaRadius * math.sin(relKaabaRad);
      final ky = _kaabaRadius * math.cos(relKaabaRad);
      final kaabaGlowPt = project(_Vec3(kx, ky, 0.38));
      final glowR = size.shortestSide * (0.20 + 0.10 * alignedGlow);
      canvas.drawCircle(
        kaabaGlowPt.offset,
        glowR,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              goldColor.withValues(
                alpha: (isDark ? 0.24 : 0.18) * alignedGlow,
              ),
              goldColor.withValues(alpha: 0.0),
            ],
          ).createShader(
            Rect.fromCircle(center: kaabaGlowPt.offset, radius: glowR),
          ),
      );
    }
  }

  void _paintGroundCompassRing(
    Canvas canvas, {
    required _ProjectedPoint Function(_Vec3, {double depthBias}) project,
    required double visualHeadingDeg,
    required double deltaDeg,
    required double alignedGlow,
    required bool isLockedVisual,
  }) {
    final ringPath = Path();
    final innerRingPath = Path();
    const segments = 72;
    for (var i = 0; i <= segments; i++) {
      final angle = (i / segments) * 2.0 * math.pi;
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);
      final pOuter = project(_Vec3(_ringRadius * sinA, _ringRadius * cosA, 0.0));
      final pInner = project(
        _Vec3((_ringRadius - 0.17) * sinA, (_ringRadius - 0.17) * cosA, 0.0),
      );
      if (i == 0) {
        ringPath.moveTo(pOuter.offset.dx, pOuter.offset.dy);
        innerRingPath.moveTo(pInner.offset.dx, pInner.offset.dy);
      } else {
        ringPath.lineTo(pOuter.offset.dx, pOuter.offset.dy);
        innerRingPath.lineTo(pInner.offset.dx, pInner.offset.dy);
      }
    }

    final baseFillColor = isDark
        ? Colors.white.withValues(alpha: 0.035)
        : accentColor.withValues(alpha: 0.04);
    canvas.drawPath(ringPath, Paint()..color = baseFillColor);

    // 8 Köşeli Selçuklu Yıldızı zemini
    _paintSeljukFloorRosette(canvas, project);

    canvas.drawPath(
      ringPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isLockedVisual ? 2.4 : 1.5
        ..color = (isLockedVisual ? goldColor : accentColor)
            .withValues(alpha: 0.38 + alignedGlow * 0.45),
    );
    canvas.drawPath(
      innerRingPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = secondaryText.withValues(alpha: 0.18),
    );

    // Pusula derece çizgileri
    final northOffsetRad = -visualHeadingDeg * _degToRad;
    final tickPaint = Paint()..style = PaintingStyle.stroke;
    for (var deg = 0; deg < 360; deg += 5) {
      final a = northOffsetRad + deg * _degToRad;
      final isMajor = deg % 45 == 0;
      final isMedium = deg % 15 == 0;
      final rIn = isMajor
          ? _ringRadius - 0.13
          : (isMedium ? _ringRadius - 0.085 : _ringRadius - 0.04);
      final p1 = project(_Vec3(rIn * math.sin(a), rIn * math.cos(a), 0.0));
      final p2 = project(
        _Vec3(_ringRadius * math.sin(a), _ringRadius * math.cos(a), 0.0),
      );

      tickPaint
        ..strokeWidth = isMajor ? 1.8 : 0.85
        ..color = deg == 0
            ? const Color(0xFFD1495B).withValues(alpha: 0.88)
            : secondaryText.withValues(alpha: isMajor ? 0.52 : 0.20);
      canvas.drawLine(p1.offset, p2.offset, tickPaint);
    }

    // 4 Ana yön etiketi (K/D/G/B veya N/E/S/W)
    final cardinals = isTurkish
        ? const <(int, String)>[
            (0, 'K'),
            (90, 'D'),
            (180, 'G'),
            (270, 'B'),
          ]
        : const <(int, String)>[
            (0, 'N'),
            (90, 'E'),
            (180, 'S'),
            (270, 'W'),
          ];
    for (final item in cardinals) {
      final a = northOffsetRad + item.$1 * _degToRad;
      final p = project(
        _Vec3(
          (_ringRadius + 0.17) * math.sin(a),
          (_ringRadius + 0.17) * math.cos(a),
          0.01,
        ),
      );
      _drawTextLabel(
        canvas,
        text: item.$2,
        center: p.offset,
        color: item.$1 == 0
            ? const Color(0xFFD1495B)
            : secondaryText.withValues(alpha: 0.85),
        fontSize: item.$1 == 0 ? 12.0 : 10.5,
        fontWeight: FontWeight.w800,
      );
    }

    // Yönlendirme yayı (Kullanıcının baktığı yönden Kâbe'ye)
    if (deltaDeg.abs() > QiblaMath.alignmentEnterDeg) {
      _paintGuidanceArc(canvas, project, deltaDeg);
    }

    // Güneşle Gözle Doğrulama İşareti (☀️)
    if (isSunVisible) {
      final sunRelRad =
          QiblaMath.shortestAngleDelta(visualHeadingDeg, sunAzimuthDeg) *
              _degToRad;
      final sunPos = project(
        _Vec3(
          (_ringRadius - 0.02) * math.sin(sunRelRad),
          (_ringRadius - 0.02) * math.cos(sunRelRad),
          0.06,
        ),
      );
      final centerGround = project(const _Vec3(0.0, -0.34, 0.01));
      canvas.drawLine(
        centerGround.offset,
        sunPos.offset,
        Paint()
          ..color = const Color(0xFFF59E0B).withValues(alpha: 0.16)
          ..strokeWidth = 1.0,
      );
      canvas.drawCircle(
        sunPos.offset,
        9.5,
        Paint()..color = const Color(0xFFF59E0B).withValues(alpha: 0.22),
      );
      canvas.drawCircle(
        sunPos.offset,
        5.0,
        Paint()..color = const Color(0xFFFBBF24),
      );
      canvas.drawCircle(
        sunPos.offset,
        5.0,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = Colors.white.withValues(alpha: 0.85),
      );
    }
  }

  void _paintSeljukFloorRosette(
    Canvas canvas,
    _ProjectedPoint Function(_Vec3, {double depthBias}) project,
  ) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.85
      ..color = goldColor.withValues(alpha: isDark ? 0.22 : 0.26);

    for (final offsetRad in const <double>[0.0, math.pi / 4.0]) {
      final path = Path();
      const r = 0.88;
      for (var i = 0; i < 4; i++) {
        final a = offsetRad + i * (math.pi / 2.0) + math.pi / 4.0;
        final pt = project(_Vec3(r * math.sin(a), r * math.cos(a) - 0.14, 0.0));
        if (i == 0) {
          path.moveTo(pt.offset.dx, pt.offset.dy);
        } else {
          path.lineTo(pt.offset.dx, pt.offset.dy);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  void _paintGuidanceArc(
    Canvas canvas,
    _ProjectedPoint Function(_Vec3, {double depthBias}) project,
    double deltaDeg,
  ) {
    const steps = 28;
    final path = Path();
    const r = _ringRadius - 0.08;
    Offset? prevTip;
    Offset? endTip;
    for (var i = 0; i <= steps; i++) {
      final a = (deltaDeg * (i / steps)) * _degToRad;
      final pt = project(_Vec3(r * math.sin(a), r * math.cos(a), 0.015));
      if (i == 0) {
        path.moveTo(pt.offset.dx, pt.offset.dy);
      } else {
        path.lineTo(pt.offset.dx, pt.offset.dy);
      }
      if (i == steps - 1) prevTip = pt.offset;
      if (i == steps) endTip = pt.offset;
    }

    final arcColor = deltaDeg.abs() <= QiblaMath.approachingThresholdDeg
        ? goldColor
        : accentColor;
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..color = arcColor.withValues(alpha: 0.82),
    );

    if (prevTip != null && endTip != null) {
      final dir = endTip - prevTip;
      final len = dir.distance;
      if (len > 0.5) {
        final ux = dir.dx / len;
        final uy = dir.dy / len;
        const headLen = 8.5;
        const spread = 5.0;
        final arrow = Path()
          ..moveTo(endTip.dx, endTip.dy)
          ..lineTo(
            endTip.dx - ux * headLen - uy * spread,
            endTip.dy - uy * headLen + ux * spread,
          )
          ..lineTo(
            endTip.dx - ux * headLen + uy * spread,
            endTip.dy - uy * headLen - ux * spread,
          )
          ..close();
        canvas.drawPath(
          arrow,
          Paint()..color = arcColor.withValues(alpha: 0.92),
        );
      }
    }
  }

  void _paintNurCorridor(
    Canvas canvas, {
    required _ProjectedPoint Function(_Vec3, {double depthBias}) project,
    required double relKaabaRad,
    required double intensity,
    required bool isLockedVisual,
  }) {
    final dirX = math.sin(relKaabaRad);
    final dirY = math.cos(relKaabaRad);
    final perpX = dirY;
    final perpY = -dirX;

    final startL = project(const _Vec3(-0.17, 0.42, 0.01));
    final startR = project(const _Vec3(0.17, 0.42, 0.01));
    final endL = project(
      _Vec3(
        (_kaabaRadius - 0.36) * dirX - perpX * 0.28,
        (_kaabaRadius - 0.36) * dirY - perpY * 0.28,
        0.01,
      ),
    );
    final endR = project(
      _Vec3(
        (_kaabaRadius - 0.36) * dirX + perpX * 0.28,
        (_kaabaRadius - 0.36) * dirY + perpY * 0.28,
        0.01,
      ),
    );

    final path = Path()
      ..moveTo(startL.offset.dx, startL.offset.dy)
      ..lineTo(startR.offset.dx, startR.offset.dy)
      ..lineTo(endR.offset.dx, endR.offset.dy)
      ..lineTo(endL.offset.dx, endL.offset.dy)
      ..close();

    final beamColor = isLockedVisual ? goldColor : accentColor;
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: <Color>[
            beamColor.withValues(alpha: 0.14 + intensity * 0.30),
            goldColor.withValues(alpha: 0.06 + intensity * 0.22),
          ],
        ).createShader(path.getBounds()),
    );
  }

  void _paintTakbirGroundRipple(
    Canvas canvas, {
    required _ProjectedPoint Function(_Vec3, {double depthBias}) project,
    required double takbirProgress,
  }) {
    final t = (takbirProgress / 0.85).clamp(0.0, 1.0);
    final r = 0.32 + t * 0.78;
    final alpha = (1.0 - t) * 0.55;
    final path = Path();
    const segs = 36;
    for (var i = 0; i <= segs; i++) {
      final a = (i / segs) * 2.0 * math.pi;
      final pt = project(_Vec3(r * math.sin(a), -0.34 + r * math.cos(a), 0.015));
      if (i == 0) {
        path.moveTo(pt.offset.dx, pt.offset.dy);
      } else {
        path.lineTo(pt.offset.dx, pt.offset.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = goldColor.withValues(alpha: alpha),
    );
  }

  void _buildPrayerRugFaces(
    List<_Face3D> faces, {
    required _ProjectedPoint Function(_Vec3, {double depthBias}) project,
    required _Vec3 lightDir,
    required double alignedGlow,
    required bool isLockedVisual,
  }) {
    final rugBase = isLockedVisual
        ? Color.lerp(accentColor, const Color(0xFF1F7A5C), 0.35)!
        : accentColor;
    final rugBorder = Color.lerp(rugBase, goldColor, 0.34)!;
    final rugTrim = isLockedVisual ? goldColor : const Color(0xFFE7C67E);

    // Seccade zemini: y = -0.64 .. +0.40 (figür baseY = -0.34 konumunda, Kâbe önü tamamen açık)
    final rugSurfaceDepth = project(const _Vec3(0.0, -0.12, 0.028)).depth;

    _addOrientedBox(
      faces,
      project: project,
      lightDir: lightDir,
      center: const _Vec3(0.0, -0.12, 0.014),
      halfSize: const _Vec3(0.24, 0.52, 0.014),
      yawRad: 0.0,
      baseColor: rugBase,
      strokeColor: rugTrim.withValues(alpha: 0.40),
      depthBias: 0.02,
    );

    _addFlatQuad(
      faces,
      project: project,
      lightDir: lightDir,
      corners: const <_Vec3>[
        _Vec3(-0.20, -0.57, 0.029),
        _Vec3(0.20, -0.57, 0.029),
        _Vec3(0.20, 0.34, 0.029),
        _Vec3(-0.20, 0.34, 0.029),
      ],
      color: rugBorder,
      stroke: rugTrim.withValues(alpha: 0.65),
      depthOverride: rugSurfaceDepth - 0.01,
    );

    _addFlatQuad(
      faces,
      project: project,
      lightDir: lightDir,
      corners: const <_Vec3>[
        _Vec3(-0.155, -0.50, 0.030),
        _Vec3(0.155, -0.50, 0.030),
        _Vec3(0.155, 0.20, 0.030),
        _Vec3(-0.155, 0.20, 0.030),
      ],
      color: Color.lerp(rugBase, Colors.black, 0.14)!,
      depthOverride: rugSurfaceDepth - 0.02,
    );

    // İleri (+Y) bakan altın mihrap kemeri
    _addFlatTriangle(
      faces,
      project: project,
      lightDir: lightDir,
      a: const _Vec3(-0.135, 0.18, 0.031),
      b: const _Vec3(0.135, 0.18, 0.031),
      c: const _Vec3(0.0, 0.32, 0.031),
      color: Color.lerp(rugTrim, Colors.white, alignedGlow * 0.25)!,
      stroke: goldColor.withValues(alpha: 0.85),
      depthOverride: rugSurfaceDepth - 0.03,
    );

    // Ön ve arka püsküller
    for (var i = -3; i <= 3; i++) {
      final tx = i * 0.062;
      _addFlatQuad(
        faces,
        project: project,
        lightDir: lightDir,
        corners: <_Vec3>[
          _Vec3(tx - 0.010, 0.40, 0.012),
          _Vec3(tx + 0.010, 0.40, 0.012),
          _Vec3(tx + 0.008, 0.455, 0.004),
          _Vec3(tx - 0.008, 0.455, 0.004),
        ],
        color: rugTrim.withValues(alpha: 0.85),
        depthOverride: rugSurfaceDepth + 0.03,
      );
      _addFlatQuad(
        faces,
        project: project,
        lightDir: lightDir,
        corners: <_Vec3>[
          _Vec3(tx - 0.010, -0.64, 0.012),
          _Vec3(tx + 0.010, -0.64, 0.012),
          _Vec3(tx + 0.008, -0.695, 0.004),
          _Vec3(tx - 0.008, -0.695, 0.004),
        ],
        color: rugTrim.withValues(alpha: 0.85),
        depthOverride: rugSurfaceDepth + 0.03,
      );
    }

    if (figureMode != QiblaFigureMode.prayerRugOnly) {
      _addFlatDisc(
        faces,
        project: project,
        center: const _Vec3(0.0, -0.34, 0.031),
        rx: 0.145,
        ry: 0.105,
        segments: 16,
        color: Colors.black.withValues(alpha: 0.28),
        depthOverride: rugSurfaceDepth - 0.04,
      );
    }
  }

  void _buildKaabaSanctuaryFaces(
    List<_Face3D> faces, {
    required _ProjectedPoint Function(_Vec3, {double depthBias}) project,
    required _Vec3 lightDir,
    required double relKaabaRad,
    required double alignedGlow,
    required bool isLockedVisual,
  }) {
    final kx = _kaabaRadius * math.sin(relKaabaRad);
    final ky = _kaabaRadius * math.cos(relKaabaRad);
    final cosK = math.cos(relKaabaRad);
    final sinK = math.sin(relKaabaRad);

    _Vec3 localToKaaba(double lx, double ly, double lz) => _Vec3(
          kx + lx * cosK + ly * sinK,
          ky - lx * sinK + ly * cosK,
          lz,
        );

    final marbleLight = isDark
        ? const Color(0xFFE4E0D8)
        : const Color(0xFFF6F2E9);
    final marbleTrim = goldColor.withValues(alpha: 0.45);

    // 1. Mataf Mermer Avlu Kaidesi (16 kenarlı geniş avlu platformu)
    _addSculptedLoft(
      faces,
      project: project,
      lightDir: lightDir,
      center: _Vec3(kx, ky, 0.0),
      segments: 16,
      depthBias: 0.03,
      includeTopCap: true,
      rings: <_LoftRing>[
        _LoftRing(
          z: 0.000,
          rx: 0.46,
          ry: 0.46,
          bandColor: marbleLight,
        ),
        _LoftRing(
          z: 0.036,
          rx: 0.44,
          ry: 0.44,
          bandColor: marbleLight,
        ),
      ],
      topCapColor: marbleLight,
      strokeColor: marbleTrim,
    );

    // 2. Hatim (Hicr-i İsmail) — Kâbe sol yanında yarım daire mermer duvarı
    const hatimSegs = 7;
    for (var i = 0; i < hatimSegs; i++) {
      final a = math.pi * 0.62 + (i / (hatimSegs - 1)) * (math.pi * 0.76);
      final hx = 0.37 * math.cos(a) - 0.04;
      final hy = 0.37 * math.sin(a);
      _addOrientedBox(
        faces,
        project: project,
        lightDir: lightDir,
        center: localToKaaba(hx, hy, 0.068),
        halfSize: const _Vec3(0.030, 0.042, 0.032),
        yawRad: relKaabaRad + a,
        baseColor: marbleLight,
        strokeColor: goldColor.withValues(alpha: 0.35),
      );
    }

    // 3. Şadervan Mermer Kaide Basamağı (Kâbe gövdesinin hemen altı)
    _addOrientedBox(
      faces,
      project: project,
      lightDir: lightDir,
      center: localToKaaba(0.0, 0.0, 0.071),
      halfSize: const _Vec3(0.312, 0.312, 0.035),
      yawRad: relKaabaRad,
      baseColor: marbleLight,
      strokeColor: marbleTrim,
    );

    // 4. Anıtsal Kâbe Küpü (Kisve-i Şerîfe — z: 0.106 .. 0.786)
    final stoneColor = isLockedVisual
        ? const Color(0xFF1A1E26)
        : const Color(0xFF14171D);
    final edgeStroke = Color.lerp(
      goldColor.withValues(alpha: 0.45),
      const Color(0xFFFFE599).withValues(alpha: 0.85),
      alignedGlow,
    )!;
    _addOrientedBox(
      faces,
      project: project,
      lightDir: lightDir,
      center: localToKaaba(0.0, 0.0, 0.446),
      halfSize: const _Vec3(0.285, 0.285, 0.340),
      yawRad: relKaabaRad,
      baseColor: stoneColor,
      strokeColor: edgeStroke,
      strokeWidth: 0.8,
    );
    final kaabaFrontDepth = project(localToKaaba(0.0, -0.285, 0.446)).depth;

    // 5. Altın Hizam Kuşağı (üst 1/3 dilim)
    _addOrientedBox(
      faces,
      project: project,
      lightDir: lightDir,
      center: localToKaaba(0.0, 0.0, 0.600),
      halfSize: const _Vec3(0.292, 0.292, 0.036),
      yawRad: relKaabaRad,
      baseColor: const Color(0xFFE5B84B),
      strokeColor: const Color(0xFFFFE8A3).withValues(alpha: 0.78),
      depthBias: -0.02,
    );

    // 6. Kâbe Altın Kapısı (Bâb-ı Kâbe) + Sitâre Alınlığı + Köşe Madalyonları
    // Merkeze bakan ön yüz (ly = -0.290) — ön duvarın arkasında kalmaması için açık depthOverride
    _addFlatQuad(
      faces,
      project: project,
      lightDir: lightDir,
      corners: <_Vec3>[
        localToKaaba(0.015, -0.289, 0.215),
        localToKaaba(0.125, -0.289, 0.215),
        localToKaaba(0.125, -0.289, 0.475),
        localToKaaba(0.015, -0.289, 0.475),
      ],
      color: const Color(0xFFF3C65F),
      stroke: const Color(0xFFFFF4C2),
      depthOverride: kaabaFrontDepth - 0.018,
      cullBackface: true,
    );
    // Kapı içi kabartma paneli
    _addFlatQuad(
      faces,
      project: project,
      lightDir: lightDir,
      corners: <_Vec3>[
        localToKaaba(0.032, -0.292, 0.235),
        localToKaaba(0.108, -0.292, 0.235),
        localToKaaba(0.108, -0.292, 0.455),
        localToKaaba(0.032, -0.292, 0.455),
      ],
      color: const Color(0xFFD99E30),
      stroke: const Color(0xFFFFF1B8),
      depthOverride: kaabaFrontDepth - 0.024,
      cullBackface: true,
    );
    // Hizam altında iki altın Samediye madalyonu (ön yüz)
    for (final mx in const <double>[-0.14, 0.14]) {
      _addFlatQuad(
        faces,
        project: project,
        lightDir: lightDir,
        corners: <_Vec3>[
          localToKaaba(mx - 0.022, -0.290, 0.500),
          localToKaaba(mx + 0.022, -0.290, 0.500),
          localToKaaba(mx + 0.022, -0.290, 0.535),
          localToKaaba(mx - 0.022, -0.290, 0.535),
        ],
        color: const Color(0xFFE5B84B),
        stroke: const Color(0xFFFFE8A3).withValues(alpha: 0.75),
        depthOverride: kaabaFrontDepth - 0.018,
        cullBackface: true,
      );
    }

    // 7. Hacerü'l-Esved Köşe Çerçevesi (Ön-sağ Rükn)
    _addOrientedBox(
      faces,
      project: project,
      lightDir: lightDir,
      center: localToKaaba(0.285, -0.285, 0.255),
      halfSize: const _Vec3(0.022, 0.022, 0.042),
      yawRad: relKaabaRad,
      baseColor: const Color(0xFFD9E2EC),
      strokeColor: const Color(0xFF94A3B8),
      depthBias: -0.15,
    );

    // 8. Makâm-ı İbrâhim (Kâbe ön-sağ avluda zarif altın kubbeli yapı)
    _addTaperedCylinder(
      faces,
      project: project,
      lightDir: lightDir,
      start: localToKaaba(0.32, -0.34, 0.036),
      end: localToKaaba(0.32, -0.34, 0.125),
      rStart: 0.036,
      rEnd: 0.030,
      segments: 10,
      baseColor: marbleLight,
      strokeColor: marbleTrim,
    );
    _addSphereShell(
      faces,
      project: project,
      lightDir: lightDir,
      center: localToKaaba(0.32, -0.34, 0.126),
      radius: 0.034,
      phiStart: 0.0,
      phiEnd: math.pi * 0.5,
      thetaStart: 0.0,
      thetaEnd: math.pi * 2.0,
      stacks: 4,
      slices: 10,
      baseColor: const Color(0xFFE8B949),
    );
  }

  void _buildMihrabArchFaces(
    List<_Face3D> faces, {
    required _ProjectedPoint Function(_Vec3, {double depthBias}) project,
    required _Vec3 lightDir,
    required double alignedGlow,
  }) {
    final breath = math.sin(breathPhase * 2.0 * math.pi) * 0.012;
    final archColor = Color.lerp(
      goldColor,
      const Color(0xFFFFF3C4),
      0.25 + takbirProgress * 0.45,
    )!;
    const pillarBaseY = 0.24;

    _addTaperedCylinder(
      faces,
      project: project,
      lightDir: lightDir,
      start: const _Vec3(-0.14, pillarBaseY, 0.03),
      end: const _Vec3(-0.14, pillarBaseY, 0.34),
      rStart: 0.020,
      rEnd: 0.016,
      segments: 10,
      baseColor: archColor,
    );
    _addTaperedCylinder(
      faces,
      project: project,
      lightDir: lightDir,
      start: const _Vec3(0.14, pillarBaseY, 0.03),
      end: const _Vec3(0.14, pillarBaseY, 0.34),
      rStart: 0.020,
      rEnd: 0.016,
      segments: 10,
      baseColor: archColor,
    );
    _addTaperedCylinder(
      faces,
      project: project,
      lightDir: lightDir,
      start: const _Vec3(-0.14, pillarBaseY, 0.335),
      end: _Vec3(0.0, pillarBaseY + 0.03, 0.47 + breath),
      rStart: 0.018,
      rEnd: 0.018,
      segments: 10,
      baseColor: archColor,
    );
    _addTaperedCylinder(
      faces,
      project: project,
      lightDir: lightDir,
      start: const _Vec3(0.14, pillarBaseY, 0.335),
      end: _Vec3(0.0, pillarBaseY + 0.03, 0.47 + breath),
      rStart: 0.018,
      rEnd: 0.018,
      segments: 10,
      baseColor: archColor,
    );

    final gemLift = 0.22 + takbirProgress * 0.10 + alignedGlow * 0.03 + breath;
    _addSphereShell(
      faces,
      project: project,
      lightDir: lightDir,
      center: _Vec3(0.0, -0.08, gemLift),
      radius: 0.052 + takbirProgress * 0.014,
      phiStart: -math.pi * 0.5,
      phiEnd: math.pi * 0.5,
      thetaStart: 0.0,
      thetaEnd: math.pi * 2.0,
      stacks: 6,
      slices: 12,
      baseColor: archColor,
    );
  }

  void _buildCharacterFaces(
    List<_Face3D> faces, {
    required _ProjectedPoint Function(_Vec3, {double depthBias}) project,
    required _Vec3 lightDir,
    required double deltaDeg,
  }) {
    final isFemale = figureMode == QiblaFigureMode.female;
    final breath = math.sin(breathPhase * 2.0 * math.pi) * 0.006;
    const baseY = -0.34;
    const baseZ = 0.030;

    // Dikişsiz kumaş ve deri paleti (0.68 dünya birimi boy -> Kâbe'nin altında dengeli ön plan)
    final skinTone = isDark
        ? const Color(0xFFEAD9C3)
        : const Color(0xFFF3E4D0);
    final kaftanPrimary = isFemale
        ? Color.lerp(accentColor, const Color(0xFF194B42), 0.34)!
        : Color.lerp(accentColor, const Color(0xFF143C32), 0.38)!;
    final creamFabric = isDark
        ? const Color(0xFFEDE7DC)
        : const Color(0xFFF8F4EC);
    final sashColor = isFemale
        ? Color.lerp(goldColor, kaftanPrimary, 0.42)!
        : Color.lerp(goldColor, const Color(0xFF8C6239), 0.35)!;
    final goldTrim = Color.lerp(goldColor, const Color(0xFFF4D078), 0.42)!;
    final headgearColor = isFemale
        ? const Color(0xFFF5EFE3)
        : const Color(0xFFFAF7F0);
    final innerBonnetColor = Color.lerp(kaftanPrimary, Colors.black, 0.18)!;
    const mestColor = Color(0xFF38302A);

    // 1. Mest / Namaz Çorabı (seccadeye sağlam basan ayaklar)
    for (final side in const <double>[-1.0, 1.0]) {
      _addOrientedBox(
        faces,
        project: project,
        lightDir: lightDir,
        center: _Vec3(side * 0.045, baseY + 0.020, baseZ + 0.015),
        halfSize: const _Vec3(0.025, 0.052, 0.015),
        yawRad: -side * 0.06,
        baseColor: mestColor,
      );
    }

    // 2. Sürekli Tek Parça Biçimli Gövde ve Kaftan / Ferace (Örtüşen iç-dış Z-çakışması yok)
    final waistZ = baseZ + 0.345 + breath * 0.35;
    final shoulderZ = baseZ + 0.505 + breath;

    if (isFemale) {
      // 2A. Kadın: A-Kesim Yumuşak Pileli Ferace + Zarif Kemer Şeridi
      _addSculptedLoft(
        faces,
        project: project,
        lightDir: lightDir,
        center: const _Vec3(0.0, baseY, 0.0),
        segments: 24,
        pleatCount: 6,
        includeTopCap: false,
        rings: <_LoftRing>[
          _LoftRing(
            z: baseZ + 0.028,
            rx: 0.146,
            ry: 0.118,
            pleatAmp: 0.008,
            bandColor: goldTrim,
          ),
          _LoftRing(
            z: baseZ + 0.044,
            rx: 0.144,
            ry: 0.116,
            pleatAmp: 0.008,
            bandColor: goldTrim,
          ),
          _LoftRing(
            z: baseZ + 0.185,
            rx: 0.118,
            ry: 0.092,
            pleatAmp: 0.005,
            bandColor: kaftanPrimary,
          ),
          _LoftRing(
            z: waistZ - 0.012,
            rx: 0.095,
            ry: 0.074,
            pleatAmp: 0.002,
            bandColor: kaftanPrimary,
          ),
          _LoftRing(
            z: waistZ + 0.018,
            rx: 0.096,
            ry: 0.075,
            pleatAmp: 0.0,
            bandColor: sashColor,
          ),
          _LoftRing(
            z: shoulderZ - 0.010,
            rx: 0.108,
            ry: 0.072,
            pleatAmp: 0.0,
            bandColor: kaftanPrimary,
          ),
          _LoftRing(
            z: shoulderZ + 0.016,
            rx: 0.056,
            ry: 0.052,
            pleatAmp: 0.0,
            bandColor: headgearColor,
          ),
        ],
      );

      // Omuzları ve sırtı örten krem Başörtüsü / Hımâr Pelerini (gövdeden geniş, sıfır delme)
      _addSculptedLoft(
        faces,
        project: project,
        lightDir: lightDir,
        center: const _Vec3(0.0, baseY - 0.006, 0.0),
        segments: 24,
        pleatCount: 6,
        includeTopCap: false,
        rings: <_LoftRing>[
          _LoftRing(
            z: waistZ + 0.024,
            rx: 0.126,
            ry: 0.094,
            pleatAmp: 0.004,
            bandColor: goldTrim,
          ),
          _LoftRing(
            z: waistZ + 0.036,
            rx: 0.124,
            ry: 0.092,
            pleatAmp: 0.004,
            bandColor: goldTrim,
          ),
          _LoftRing(
            z: shoulderZ - 0.025,
            rx: 0.120,
            ry: 0.088,
            pleatAmp: 0.002,
            bandColor: headgearColor,
          ),
          _LoftRing(
            z: shoulderZ + 0.038,
            rx: 0.064,
            ry: 0.062,
            pleatAmp: 0.0,
            bandColor: headgearColor,
          ),
        ],
      );
    } else {
      // 2B. Erkek: Krem İç Entari Eteği -> Altın Şeritli Pileli Cübbe -> Dokuma Kuşak -> Hakim Yaka
      _addSculptedLoft(
        faces,
        project: project,
        lightDir: lightDir,
        center: const _Vec3(0.0, baseY, 0.0),
        segments: 24,
        pleatCount: 6,
        includeTopCap: false,
        rings: <_LoftRing>[
          _LoftRing(
            z: baseZ + 0.032,
            rx: 0.106,
            ry: 0.084,
            pleatAmp: 0.003,
            bandColor: creamFabric,
          ),
          _LoftRing(
            z: baseZ + 0.072,
            rx: 0.108,
            ry: 0.085,
            pleatAmp: 0.003,
            bandColor: creamFabric,
          ),
          _LoftRing(
            z: baseZ + 0.074,
            rx: 0.125,
            ry: 0.096,
            pleatAmp: 0.006,
            bandColor: goldTrim,
          ),
          _LoftRing(
            z: baseZ + 0.089,
            rx: 0.123,
            ry: 0.095,
            pleatAmp: 0.006,
            bandColor: goldTrim,
          ),
          _LoftRing(
            z: baseZ + 0.225,
            rx: 0.108,
            ry: 0.083,
            pleatAmp: 0.004,
            bandColor: kaftanPrimary,
          ),
          _LoftRing(
            z: waistZ - 0.006,
            rx: 0.098,
            ry: 0.076,
            pleatAmp: 0.001,
            bandColor: kaftanPrimary,
          ),
          _LoftRing(
            z: waistZ + 0.030,
            rx: 0.100,
            ry: 0.078,
            pleatAmp: 0.0,
            bandColor: sashColor,
          ),
          _LoftRing(
            z: shoulderZ - 0.045,
            rx: 0.112,
            ry: 0.080,
            pleatAmp: 0.001,
            bandColor: kaftanPrimary,
          ),
          _LoftRing(
            z: shoulderZ - 0.006,
            rx: 0.122,
            ry: 0.078,
            pleatAmp: 0.0,
            bandColor: kaftanPrimary,
          ),
          _LoftRing(
            z: shoulderZ + 0.010,
            rx: 0.076,
            ry: 0.056,
            pleatAmp: 0.0,
            bandColor: goldTrim,
          ),
          _LoftRing(
            z: shoulderZ + 0.032,
            rx: 0.046,
            ry: 0.044,
            pleatAmp: 0.0,
            bandColor: creamFabric,
          ),
        ],
      );
    }

    // 3. Baş Yönelimi: Ararken Kâbe'ye hafif bakış; Tekbir/Kıyamda secde mahalline huşû eğilişi
    final glanceWeight = (1.0 - takbirProgress * 1.4).clamp(0.0, 1.0);
    final headYawRad =
        (deltaDeg.clamp(-34.0, 34.0) * glanceWeight) * _degToRad;
    final headNodForward = takbirProgress * 0.016;
    final headCenter = _Vec3(
      math.sin(headYawRad) * 0.008,
      baseY + headNodForward,
      shoulderZ + 0.105,
    );

    // Boyun
    _addTaperedCylinder(
      faces,
      project: project,
      lightDir: lightDir,
      start: _Vec3(0.0, baseY, shoulderZ + 0.008),
      end: headCenter + const _Vec3(0.0, 0.0, -0.040),
      rStart: 0.038,
      rEnd: 0.034,
      segments: 12,
      baseColor: isFemale ? headgearColor : skinTone,
    );

    // 4. Baş & Başlık: Küre parçalarıyla sıfır Z-çakışması
    if (isFemale) {
      // Ön yüz (+Y sektör) cilt + kemer bandı + arka/yan/tepe tümüyle tek parça krem Başörtüsü
      _addSphereShell(
        faces,
        project: project,
        lightDir: lightDir,
        center: headCenter,
        radius: 0.068,
        phiStart: -math.pi * 0.36,
        phiEnd: math.pi * 0.20,
        thetaStart: math.pi * 0.34,
        thetaEnd: math.pi * 0.66,
        yawOffsetRad: headYawRad,
        stacks: 4,
        slices: 6,
        baseColor: skinTone,
      );
      // İnce ön alın bone şeridi
      _addSphereShell(
        faces,
        project: project,
        lightDir: lightDir,
        center: headCenter,
        radius: 0.070,
        phiStart: math.pi * 0.19,
        phiEnd: math.pi * 0.34,
        thetaStart: math.pi * 0.32,
        thetaEnd: math.pi * 0.68,
        yawOffsetRad: headYawRad,
        stacks: 2,
        slices: 6,
        baseColor: innerBonnetColor,
      );
      // Başörtüsü üst kubbe + arka döküm (tüm baş tacı ve arka yarımküre)
      _addSphereShell(
        faces,
        project: project,
        lightDir: lightDir,
        center: headCenter,
        radius: 0.072,
        phiStart: math.pi * 0.32,
        phiEnd: math.pi * 0.50,
        thetaStart: 0.0,
        thetaEnd: math.pi * 2.0,
        yawOffsetRad: headYawRad,
        stacks: 4,
        slices: 14,
        baseColor: headgearColor,
      );
      _addSphereShell(
        faces,
        project: project,
        lightDir: lightDir,
        center: headCenter,
        radius: 0.072,
        phiStart: -math.pi * 0.42,
        phiEnd: math.pi * 0.33,
        thetaStart: math.pi * 0.65,
        thetaEnd: math.pi * 2.35,
        yawOffsetRad: headYawRad,
        stacks: 5,
        slices: 12,
        baseColor: headgearColor,
      );
    } else {
      // Erkek baş alt yarı (ten) + Altın Nakış Şerit + Fildişi Takke Üst Kubbesi
      _addSphereShell(
        faces,
        project: project,
        lightDir: lightDir,
        center: headCenter,
        radius: 0.062,
        phiStart: -math.pi * 0.50,
        phiEnd: 0.25,
        thetaStart: 0.0,
        thetaEnd: math.pi * 2.0,
        yawOffsetRad: headYawRad,
        stacks: 5,
        slices: 14,
        baseColor: skinTone,
      );
      _addSphereShell(
        faces,
        project: project,
        lightDir: lightDir,
        center: headCenter,
        radius: 0.065,
        phiStart: 0.24,
        phiEnd: 0.40,
        thetaStart: 0.0,
        thetaEnd: math.pi * 2.0,
        yawOffsetRad: headYawRad,
        stacks: 2,
        slices: 14,
        baseColor: goldTrim,
      );
      _addSphereShell(
        faces,
        project: project,
        lightDir: lightDir,
        center: headCenter,
        radius: 0.065,
        phiStart: 0.39,
        phiEnd: math.pi * 0.50,
        thetaStart: 0.0,
        thetaEnd: math.pi * 2.0,
        yawOffsetRad: headYawRad,
        stacks: 4,
        slices: 14,
        baseColor: headgearColor,
      );
    }

    // 5. Eklemli Kollar, Yenler, Manşetler & İftitah Tekbiri -> Kıyam İskelet İnterpolasyonu
    final tRaise = Curves.easeInOutCubic.transform(
      (takbirProgress / 0.48).clamp(0.0, 1.0),
    );
    final tFold = Curves.easeInOutCubic.transform(
      ((takbirProgress - 0.56) / 0.44).clamp(0.0, 1.0),
    );

    final shoulderHalfW = isFemale ? 0.106 : 0.120;
    final leftShoulder = _Vec3(-shoulderHalfW, baseY, shoulderZ - 0.026);
    final rightShoulder = _Vec3(shoulderHalfW, baseY, shoulderZ - 0.026);

    // Yuvarlak omuz kapakları
    for (final sPt in <_Vec3>[leftShoulder, rightShoulder]) {
      _addSphereShell(
        faces,
        project: project,
        lightDir: lightDir,
        center: sPt,
        radius: 0.036,
        phiStart: -math.pi * 0.5,
        phiEnd: math.pi * 0.5,
        thetaStart: 0.0,
        thetaEnd: math.pi * 2.0,
        stacks: 5,
        slices: 10,
        baseColor: isFemale ? headgearColor : kaftanPrimary,
      );
    }

    final idleElbowL =
        _Vec3(-(shoulderHalfW + 0.028), baseY - 0.006, baseZ + 0.395 + breath);
    final idleElbowR =
        _Vec3(shoulderHalfW + 0.028, baseY - 0.006, baseZ + 0.395 + breath);
    final idleWristL =
        _Vec3(-(shoulderHalfW + 0.018), baseY + 0.032, baseZ + 0.255 + breath);
    final idleWristR =
        _Vec3(shoulderHalfW + 0.018, baseY + 0.032, baseZ + 0.255 + breath);

    // Tekbir zirvesi (kulak / omuz hizasında belirgin dua tekbiri açılımı)
    final takbirElbowL = isFemale
        ? const _Vec3(-0.175, baseY + 0.035, baseZ + 0.475)
        : const _Vec3(-0.205, baseY + 0.035, baseZ + 0.545);
    final takbirElbowR = isFemale
        ? const _Vec3(0.175, baseY + 0.035, baseZ + 0.475)
        : const _Vec3(0.205, baseY + 0.035, baseZ + 0.545);
    final takbirWristL = isFemale
        ? const _Vec3(-0.105, baseY + 0.088, baseZ + 0.555)
        : const _Vec3(-0.118, baseY + 0.062, baseZ + 0.635);
    final takbirWristR = isFemale
        ? const _Vec3(0.105, baseY + 0.088, baseZ + 0.555)
        : const _Vec3(0.118, baseY + 0.062, baseZ + 0.635);

    // Kıyam duruşu (Erkek: göbek altında sağ üstte; Kadın: göğüs üstünde)
    final qiyamElbowL =
        _Vec3(-(shoulderHalfW + 0.032), baseY + 0.024, baseZ + 0.415 + breath);
    final qiyamElbowR =
        _Vec3(shoulderHalfW + 0.032, baseY + 0.024, baseZ + 0.415 + breath);
    final qiyamWristL = isFemale
        ? _Vec3(-0.014, baseY + 0.105, baseZ + 0.455 + breath)
        : _Vec3(-0.014, baseY + 0.102, baseZ + 0.375 + breath);
    final qiyamWristR = isFemale
        ? _Vec3(0.014, baseY + 0.118, baseZ + 0.464 + breath)
        : _Vec3(0.014, baseY + 0.116, baseZ + 0.384 + breath);

    _Vec3 lerpVec(_Vec3 a, _Vec3 b, double t) => a + (b - a) * t;

    final elbowL = lerpVec(
      lerpVec(idleElbowL, takbirElbowL, tRaise),
      qiyamElbowL,
      tFold,
    );
    final elbowR = lerpVec(
      lerpVec(idleElbowR, takbirElbowR, tRaise),
      qiyamElbowR,
      tFold,
    );
    final wristL = lerpVec(
      lerpVec(idleWristL, takbirWristL, tRaise),
      qiyamWristL,
      tFold,
    );
    final wristR = lerpVec(
      lerpVec(idleWristR, takbirWristR, tRaise),
      qiyamWristR,
      tFold,
    );

    final sleeveColor = kaftanPrimary;
    final upperSleeveColor = isFemale ? headgearColor : kaftanPrimary;

    void buildArm(_Vec3 shoulder, _Vec3 elbow, _Vec3 wrist) {
      final forearmDir = (wrist - elbow).normalized();
      final cuffStart = wrist - forearmDir * 0.022;
      final handEnd = wrist + forearmDir * 0.038;

      _addTaperedCylinder(
        faces,
        project: project,
        lightDir: lightDir,
        start: shoulder,
        end: elbow,
        rStart: 0.035,
        rEnd: 0.036,
        segments: 12,
        baseColor: upperSleeveColor,
      );
      _addSphereShell(
        faces,
        project: project,
        lightDir: lightDir,
        center: elbow,
        radius: 0.036,
        phiStart: -math.pi * 0.5,
        phiEnd: math.pi * 0.5,
        thetaStart: 0.0,
        thetaEnd: math.pi * 2.0,
        stacks: 4,
        slices: 8,
        baseColor: sleeveColor,
      );
      _addTaperedCylinder(
        faces,
        project: project,
        lightDir: lightDir,
        start: elbow,
        end: cuffStart,
        rStart: 0.036,
        rEnd: 0.032,
        segments: 12,
        baseColor: sleeveColor,
      );
      _addTaperedCylinder(
        faces,
        project: project,
        lightDir: lightDir,
        start: cuffStart,
        end: wrist,
        rStart: 0.028,
        rEnd: 0.024,
        segments: 12,
        baseColor: isFemale ? goldTrim : creamFabric,
        strokeColor: goldTrim.withValues(alpha: 0.55),
      );
      _addTaperedCylinder(
        faces,
        project: project,
        lightDir: lightDir,
        start: wrist,
        end: handEnd,
        rStart: 0.021,
        rEnd: 0.013,
        segments: 10,
        baseColor: skinTone,
      );
    }

    buildArm(leftShoulder, elbowL, wristL);
    buildArm(rightShoulder, elbowR, wristR);
  }

  void _paintKaabaBeacon(
    Canvas canvas, {
    required _ProjectedPoint Function(_Vec3, {double depthBias}) project,
    required double relKaabaRad,
    required double alignedGlow,
    required bool isLockedVisual,
  }) {
    if (alignedGlow <= 0.15 && !isLockedVisual) return;

    final kx = _kaabaRadius * math.sin(relKaabaRad);
    final ky = _kaabaRadius * math.cos(relKaabaRad);
    final pBase = project(_Vec3(kx, ky, kaabaWorldHeight));
    final pTop = project(
      _Vec3(kx, ky, kaabaWorldHeight + 0.48 + (isLockedVisual ? 0.16 : 0.0)),
    );

    final alpha = isLockedVisual ? 0.52 : alignedGlow * 0.36;
    canvas.drawLine(
      pBase.offset,
      pTop.offset,
      Paint()
        ..strokeWidth = isLockedVisual ? 11.0 : 7.5
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: <Color>[
            goldColor.withValues(alpha: alpha),
            goldColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromPoints(pBase.offset, pTop.offset)),
    );
  }

  void _paintTakbirAuraAndCalligraphy(
    Canvas canvas, {
    required _ProjectedPoint Function(_Vec3, {double depthBias}) project,
    required double relKaabaRad,
    required double takbirProgress,
  }) {
    final peakEnvelope = math.sin(
      (takbirProgress * math.pi).clamp(0.0, math.pi),
    );
    final auraCenter = project(const _Vec3(0.0, -0.34, 0.54));

    if (peakEnvelope > 0.05) {
      final auraRadius = 38.0 + peakEnvelope * 28.0;
      canvas.drawCircle(
        auraCenter.offset,
        auraRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.9
          ..color = goldColor.withValues(alpha: peakEnvelope * 0.42),
      );
    }

    // "Allâhu Ekber" kaligrafisi Kâbe'nin üzerinde net, çakışmasız konumda görünür
    final kx = _kaabaRadius * math.sin(relKaabaRad);
    final ky = _kaabaRadius * math.cos(relKaabaRad);
    final badgePos = project(_Vec3(kx, ky, kaabaWorldHeight + 0.32));
    final textAlpha = (takbirProgress * 1.6).clamp(0.0, 1.0);
    _drawTextLabel(
      canvas,
      text: 'اَللّٰهُ أَكْبَرُ  •  Allâhu Ekber',
      center: badgePos.offset - const Offset(0, 12),
      color: (isDark ? const Color(0xFFFFE599) : accentColor)
          .withValues(alpha: textAlpha),
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
    );
  }

  void _paintSpiritLevelOverlay(
    Canvas canvas, {
    required _ProjectedPoint Function(_Vec3, {double depthBias}) project,
    required double pitchDeg,
    required double rollDeg,
  }) {
    final centerPt = project(const _Vec3(0.0, -0.10, 0.04));
    final bubbleOffset = Offset(
      (rollDeg / 45.0).clamp(-1.0, 1.0) * 24.0,
      -(pitchDeg / 45.0).clamp(-1.0, 1.0) * 16.0,
    );

    canvas.drawCircle(
      centerPt.offset,
      30.0,
      Paint()..color = cardBackground.withValues(alpha: 0.78),
    );
    canvas.drawCircle(
      centerPt.offset,
      30.0,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = const Color(0xFFF59E0B),
    );
    canvas.drawCircle(
      centerPt.offset,
      8.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = secondaryText.withValues(alpha: 0.55),
    );
    canvas.drawCircle(
      centerPt.offset + bubbleOffset,
      7.5,
      Paint()..color = const Color(0xFFF59E0B),
    );
  }

  // ==================== 3B GEOMETRİ VE DİKİŞSİZ LOFT MOTORU ====================

  Color _shadeColor(Color base, _Vec3 normal, _Vec3 lightDir) {
    final diff = normal.normalized().dot(lightDir).clamp(-0.35, 1.0);
    final factor = (0.56 + diff * 0.44).clamp(0.32, 1.12);
    final r = (base.r * 255.0 * factor).clamp(0, 255).round();
    final g = (base.g * 255.0 * factor).clamp(0, 255).round();
    final b = (base.b * 255.0 * factor).clamp(0, 255).round();
    return Color.fromARGB((base.a * 255.0).round(), r, g, b);
  }

  bool _isBackface(Offset a, Offset b, Offset c) {
    final area2 = (b.dx - a.dx) * (c.dy - a.dy) - (b.dy - a.dy) * (c.dx - a.dx);
    return area2 > 0;
  }

  void _addFlatQuad(
    List<_Face3D> faces, {
    required _ProjectedPoint Function(_Vec3, {double depthBias}) project,
    required _Vec3 lightDir,
    required List<_Vec3> corners,
    required Color color,
    Color? stroke,
    double depthBias = 0.0,
    double? depthOverride,
    bool cullBackface = false,
  }) {
    final normal = (corners[1] - corners[0]).cross(corners[2] - corners[0]);
    final pts = <Offset>[];
    var depthSum = 0.0;
    for (final c in corners) {
      final p = project(c, depthBias: depthBias);
      pts.add(p.offset);
      depthSum += p.depth;
    }
    if (cullBackface && pts.length >= 3 && _isBackface(pts[0], pts[1], pts[2])) {
      return;
    }
    final shaded = _shadeColor(color, normal, lightDir);
    faces.add(
      _Face3D(
        points: pts,
        depth: depthOverride ?? (depthSum / corners.length),
        fill: shaded,
        stroke: stroke ?? shaded,
      ),
    );
  }

  void _addFlatTriangle(
    List<_Face3D> faces, {
    required _ProjectedPoint Function(_Vec3, {double depthBias}) project,
    required _Vec3 lightDir,
    required _Vec3 a,
    required _Vec3 b,
    required _Vec3 c,
    required Color color,
    Color? stroke,
    double depthBias = 0.0,
    double? depthOverride,
  }) {
    final normal = (b - a).cross(c - a);
    final pa = project(a, depthBias: depthBias);
    final pb = project(b, depthBias: depthBias);
    final pc = project(c, depthBias: depthBias);
    final shaded = _shadeColor(color, normal, lightDir);
    faces.add(
      _Face3D(
        points: <Offset>[pa.offset, pb.offset, pc.offset],
        depth: depthOverride ?? ((pa.depth + pb.depth + pc.depth) / 3.0),
        fill: shaded,
        stroke: stroke ?? shaded,
      ),
    );
  }

  void _addFlatDisc(
    List<_Face3D> faces, {
    required _ProjectedPoint Function(_Vec3, {double depthBias}) project,
    required _Vec3 center,
    required double rx,
    required double ry,
    required int segments,
    required Color color,
    double depthBias = 0.0,
    double? depthOverride,
  }) {
    final pts = <Offset>[];
    var depthSum = 0.0;
    for (var i = 0; i < segments; i++) {
      final a = (i / segments) * 2.0 * math.pi;
      final p = project(
        _Vec3(center.x + rx * math.cos(a), center.y + ry * math.sin(a), center.z),
        depthBias: depthBias,
      );
      pts.add(p.offset);
      depthSum += p.depth;
    }
    faces.add(
      _Face3D(
        points: pts,
        depth: depthOverride ?? (depthSum / segments),
        fill: color,
      ),
    );
  }

  void _addOrientedBox(
    List<_Face3D> faces, {
    required _ProjectedPoint Function(_Vec3, {double depthBias}) project,
    required _Vec3 lightDir,
    required _Vec3 center,
    required _Vec3 halfSize,
    required double yawRad,
    required Color baseColor,
    Color? strokeColor,
    double strokeWidth = 0.55,
    double depthBias = 0.0,
  }) {
    final cosY = math.cos(yawRad);
    final sinY = math.sin(yawRad);

    _Vec3 toWorld(double lx, double ly, double lz) => _Vec3(
          center.x + lx * cosY + ly * sinY,
          center.y - lx * sinY + ly * cosY,
          center.z + lz,
        );

    final hx = halfSize.x;
    final hy = halfSize.y;
    final hz = halfSize.z;

    final v = <_Vec3>[
      toWorld(-hx, -hy, -hz),
      toWorld(hx, -hy, -hz),
      toWorld(hx, hy, -hz),
      toWorld(-hx, hy, -hz),
      toWorld(-hx, -hy, hz),
      toWorld(hx, -hy, hz),
      toWorld(hx, hy, hz),
      toWorld(-hx, hy, hz),
    ];

    const quads = <List<int>>[
      <int>[4, 5, 6, 7], // Üst
      <int>[0, 1, 5, 4], // Arka (-Y)
      <int>[2, 3, 7, 6], // Ön (+Y)
      <int>[1, 2, 6, 5], // Sağ (+X)
      <int>[3, 0, 4, 7], // Sol (-X)
    ];

    for (final q in quads) {
      final a = v[q[0]];
      final b = v[q[1]];
      final c = v[q[2]];
      final d = v[q[3]];
      final normal = (b - a).cross(c - a);
      final pa = project(a, depthBias: depthBias);
      final pb = project(b, depthBias: depthBias);
      final pc = project(c, depthBias: depthBias);
      final pd = project(d, depthBias: depthBias);

      if (_isBackface(pa.offset, pb.offset, pc.offset)) continue;

      final shaded = _shadeColor(baseColor, normal, lightDir);
      faces.add(
        _Face3D(
          points: <Offset>[pa.offset, pb.offset, pc.offset, pd.offset],
          depth: (pa.depth + pb.depth + pc.depth + pd.depth) * 0.25,
          fill: shaded,
          stroke: strokeColor ?? shaded,
          strokeWidth: strokeWidth,
        ),
      );
    }
  }

  void _addTaperedCylinder(
    List<_Face3D> faces, {
    required _ProjectedPoint Function(_Vec3, {double depthBias}) project,
    required _Vec3 lightDir,
    required _Vec3 start,
    required _Vec3 end,
    required double rStart,
    required double rEnd,
    required int segments,
    required Color baseColor,
    Color? strokeColor,
  }) {
    final axis = end - start;
    if (axis.length < 1e-5) return;
    final dir = axis.normalized();
    final ref = dir.z.abs() < 0.9 ? const _Vec3(0, 0, 1) : const _Vec3(0, 1, 0);
    // Saat yönünde dışa bakan normal tutarlılığı: u × v = dir
    final u = dir.cross(ref).normalized();
    final v = dir.cross(u).normalized();

    final bottomRing = <_Vec3>[];
    final topRing = <_Vec3>[];
    for (var i = 0; i < segments; i++) {
      final a = (i / segments) * 2.0 * math.pi;
      final radial = u * math.cos(a) + v * math.sin(a);
      bottomRing.add(start + radial * rStart);
      topRing.add(end + radial * rEnd);
    }

    for (var i = 0; i < segments; i++) {
      final next = (i + 1) % segments;
      final a = bottomRing[i];
      final b = bottomRing[next];
      final c = topRing[next];
      final d = topRing[i];

      final pa = project(a);
      final pb = project(b);
      final pc = project(c);
      final pd = project(d);

      if (_isBackface(pa.offset, pb.offset, pc.offset)) continue;

      final normal = (b - a).cross(d - a);
      final shaded = _shadeColor(baseColor, normal, lightDir);
      faces.add(
        _Face3D(
          points: <Offset>[pa.offset, pb.offset, pc.offset, pd.offset],
          depth: (pa.depth + pb.depth + pc.depth + pd.depth) * 0.25,
          fill: shaded,
          stroke: strokeColor ?? shaded,
          strokeWidth: 0.45,
        ),
      );
    }

    final topPts = <Offset>[];
    var topDepth = 0.0;
    for (final pt in topRing) {
      final p = project(pt);
      topPts.add(p.offset);
      topDepth += p.depth;
    }
    final capShaded = _shadeColor(baseColor, dir, lightDir);
    faces.add(
      _Face3D(
        points: topPts,
        depth: topDepth / segments,
        fill: capShaded,
        stroke: strokeColor ?? capShaded,
        strokeWidth: 0.45,
      ),
    );
  }

  /// Çok halkalı sürekli dikişsiz 3B kumaş / platform loft motoru (arka yüz elemeli).
  void _addSculptedLoft(
    List<_Face3D> faces, {
    required _ProjectedPoint Function(_Vec3, {double depthBias}) project,
    required _Vec3 lightDir,
    required _Vec3 center,
    required List<_LoftRing> rings,
    int segments = 24,
    int pleatCount = 0,
    Color? topCapColor,
    Color? strokeColor,
    bool includeTopCap = true,
    double depthBias = 0.0,
  }) {
    if (rings.length < 2) return;

    final sampledRings = <List<_Vec3>>[];
    for (final ring in rings) {
      final pts = <_Vec3>[];
      for (var i = 0; i < segments; i++) {
        final a = (i / segments) * 2.0 * math.pi;
        final pleatWave = pleatCount > 0 ? math.cos(pleatCount * a) : 0.0;
        final rx = ring.rx + ring.pleatAmp * pleatWave;
        final ry = ring.ry + ring.pleatAmp * pleatWave;
        pts.add(
          _Vec3(
            center.x + rx * math.cos(a),
            center.y + ry * math.sin(a),
            center.z + ring.z,
          ),
        );
      }
      sampledRings.add(pts);
    }

    for (var r = 0; r < rings.length - 1; r++) {
      final bot = sampledRings[r];
      final top = sampledRings[r + 1];
      final bandColor = rings[r + 1].bandColor;

      for (var i = 0; i < segments; i++) {
        final next = (i + 1) % segments;
        final a = bot[i];
        final b = bot[next];
        final c = top[next];
        final d = top[i];

        final pa = project(a, depthBias: depthBias);
        final pb = project(b, depthBias: depthBias);
        final pc = project(c, depthBias: depthBias);
        final pd = project(d, depthBias: depthBias);

        if (_isBackface(pa.offset, pb.offset, pc.offset)) continue;

        final normal = (b - a).cross(d - a);
        final shaded = _shadeColor(bandColor, normal, lightDir);
        faces.add(
          _Face3D(
            points: <Offset>[pa.offset, pb.offset, pc.offset, pd.offset],
            depth: (pa.depth + pb.depth + pc.depth + pd.depth) * 0.25,
            fill: shaded,
            stroke: strokeColor ?? shaded,
            strokeWidth: 0.55,
          ),
        );
      }
    }

    if (includeTopCap) {
      final topRing = sampledRings.last;
      final capPts = <Offset>[];
      var depthSum = 0.0;
      for (final pt in topRing) {
        final p = project(pt, depthBias: depthBias);
        capPts.add(p.offset);
        depthSum += p.depth;
      }
      final capColor = topCapColor ?? rings.last.bandColor;
      final shaded = _shadeColor(capColor, const _Vec3(0, 0, 1), lightDir);
      faces.add(
        _Face3D(
          points: capPts,
          depth: depthSum / segments,
          fill: shaded,
          stroke: strokeColor ?? shaded,
          strokeWidth: 0.45,
        ),
      );
    }
  }

  /// Arka yüz elemeli kısmi küre kabuğu (takke, eşarp, kubbe ve yüz sektörleri için sıfır çakışma).
  void _addSphereShell(
    List<_Face3D> faces, {
    required _ProjectedPoint Function(_Vec3, {double depthBias}) project,
    required _Vec3 lightDir,
    required _Vec3 center,
    required double radius,
    required double phiStart,
    required double phiEnd,
    required double thetaStart,
    required double thetaEnd,
    double yawOffsetRad = 0.0,
    required int stacks,
    required int slices,
    required Color baseColor,
  }) {
    for (var i = 0; i < stacks; i++) {
      final phi0 = phiStart + (i / stacks) * (phiEnd - phiStart);
      final phi1 = phiStart + ((i + 1) / stacks) * (phiEnd - phiStart);

      for (var j = 0; j < slices; j++) {
        final theta0 =
            thetaStart + (j / slices) * (thetaEnd - thetaStart) - yawOffsetRad;
        final theta1 = thetaStart +
            ((j + 1) / slices) * (thetaEnd - thetaStart) -
            yawOffsetRad;

        _Vec3 pt(double phi, double theta) => _Vec3(
              center.x + radius * math.cos(phi) * math.cos(theta),
              center.y + radius * math.cos(phi) * math.sin(theta),
              center.z + radius * math.sin(phi),
            );

        final p00 = pt(phi0, theta0);
        final p10 = pt(phi0, theta1);
        final p11 = pt(phi1, theta1);
        final p01 = pt(phi1, theta0);

        final s00 = project(p00);
        final s10 = project(p10);
        final s11 = project(p11);
        final s01 = project(p01);

        if (_isBackface(s00.offset, s10.offset, s11.offset)) continue;

        final normal =
            ((p00 + p10 + p11 + p01) * 0.25 - center).normalized();
        final shaded = _shadeColor(baseColor, normal, lightDir);

        faces.add(
          _Face3D(
            points: <Offset>[s00.offset, s10.offset, s11.offset, s01.offset],
            depth: (s00.depth + s10.depth + s11.depth + s01.depth) * 0.25,
            fill: shaded,
            stroke: shaded,
            strokeWidth: 0.55,
          ),
        );
      }
    }
  }

  void _drawTextLabel(
    Canvas canvas, {
    required String text,
    required Offset center,
    required Color color,
    required double fontSize,
    required FontWeight fontWeight,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: 0.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(canvas, Offset(center.dx - tp.width * 0.5, center.dy - tp.height * 0.5));
  }

  @override
  bool shouldRepaint(covariant Qibla3DPainter oldDelegate) {
    return oldDelegate.displayHeadingDeg != displayHeadingDeg ||
        oldDelegate.qiblaBearingDeg != qiblaBearingDeg ||
        oldDelegate.sunAzimuthDeg != sunAzimuthDeg ||
        oldDelegate.isSunVisible != isSunVisible ||
        oldDelegate.tiltDeg != tiltDeg ||
        oldDelegate.pitchDeg != pitchDeg ||
        oldDelegate.rollDeg != rollDeg ||
        oldDelegate.isPhoneFlat != isPhoneFlat ||
        oldDelegate.isInteractivePreview != isInteractivePreview ||
        oldDelegate.phase != phase ||
        oldDelegate.figureMode != figureMode ||
        oldDelegate.breathPhase != breathPhase ||
        oldDelegate.takbirProgress != takbirProgress ||
        oldDelegate.cameraOrbitProgress != cameraOrbitProgress ||
        oldDelegate.lockSnapProgress != lockSnapProgress ||
        oldDelegate.isDark != isDark ||
        oldDelegate.isTurkish != isTurkish ||
        oldDelegate.accentColor != accentColor;
  }
}
