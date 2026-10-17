import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 1:1 Vektörel Zikirce Logosu (8 Dilimli Zümrüt-Altın Rozet, Kubbe-i Hadra ve Tesbih).
/// Her ekran boyutunda ve DPI değerinde sıfır pikselleşme ile çalışır.
class ZikirceVectorLogo extends StatelessWidget {
  final double size;
  final double haloProgress;
  final double haloRotation;
  final double shimmerProgress;
  final double tesbihSwingAngle;
  final Color haloColor;

  const ZikirceVectorLogo({
    super.key,
    this.size = 188.0,
    this.haloProgress = 0.0,
    this.haloRotation = 0.0,
    this.shimmerProgress = 0.0,
    this.tesbihSwingAngle = 0.0,
    this.haloColor = const Color(0xFFD4A574),
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          size: Size.square(size),
          painter: ZikirceLogoPainter(
            haloProgress: haloProgress,
            haloRotation: haloRotation,
            shimmerProgress: shimmerProgress,
            tesbihSwingAngle: tesbihSwingAngle,
            haloColor: haloColor,
          ),
        ),
      ),
    );
  }
}

class ZikirceLogoPainter extends CustomPainter {
  final double haloProgress;
  final double haloRotation;
  final double shimmerProgress;
  final double tesbihSwingAngle;
  final Color haloColor;

  const ZikirceLogoPainter({
    required this.haloProgress,
    required this.haloRotation,
    required this.shimmerProgress,
    required this.tesbihSwingAngle,
    required this.haloColor,
  });

  static const double _canonicalSize = 512.0;
  static const double _cx = 255.5;
  static const double _cy = 256.0;
  static const double _rc = 88.0;
  static const double _dcx = 252.2;

  static const List<(double, double)> _domeProfile = [
    (186.5, 9.2),
    (189.0, 12.8),
    (192.0, 17.0),
    (195.0, 21.2),
    (198.0, 25.5),
    (201.0, 29.8),
    (204.0, 33.8),
    (207.0, 37.8),
    (210.0, 41.6),
    (213.0, 45.2),
    (216.0, 49.0),
    (219.0, 52.2),
    (222.0, 54.8),
    (225.0, 57.2),
    (228.0, 59.3),
    (231.0, 61.0),
    (234.0, 62.4),
    (237.0, 63.6),
    (240.0, 64.8),
    (243.0, 65.8),
    (246.0, 66.6),
    (249.0, 67.3),
    (252.0, 68.0),
    (255.0, 68.5),
    (258.0, 69.0),
    (261.0, 69.3),
    (264.0, 69.5),
    (268.0, 69.8),
    (272.0, 70.0),
  ];

  static const List<(double, double, double, double)> _upperWindows = [
    (189.5, 293.0, 5.8, 9.0),
    (211.0, 291.2, 6.2, 9.5),
    (237.0, 289.8, 6.4, 9.8),
    (267.5, 289.8, 6.4, 9.8),
    (293.0, 291.2, 6.2, 9.5),
    (314.5, 293.0, 5.8, 9.0),
  ];

  static const List<(double, double, double, double)> _lowerWindows = [
    (187.5, 312.5, 7.2, 11.2),
    (210.0, 310.8, 7.8, 11.8),
    (236.5, 309.5, 8.2, 12.0),
    (268.0, 309.5, 8.2, 12.0),
    (294.0, 310.8, 7.8, 11.8),
    (317.0, 312.5, 7.2, 11.2),
  ];

  static const List<(double, double, double)> _leftBeads = [
    (314.5, 148.5, 4.6),
    (310.5, 157.5, 4.7),
    (308.5, 167.0, 4.7),
    (308.5, 176.8, 4.7),
    (309.5, 186.6, 4.7),
    (312.5, 196.4, 4.7),
    (317.2, 206.0, 4.7),
    (323.2, 215.2, 4.7),
    (330.5, 223.8, 4.7),
    (338.8, 231.8, 4.7),
  ];

  static const List<(double, double, double)> _rightBeads = [
    (371.2, 202.0, 4.6),
    (370.5, 211.8, 4.7),
    (367.5, 221.5, 4.7),
    (361.8, 230.2, 4.7),
    (354.8, 236.8, 4.6),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _canonicalSize;
    canvas.save();
    canvas.scale(scale, scale);

    // 0. Ruhani Altın-Zümrüt Nur Hâlesi (Halo & İslami Geometrik Halka)
    if (haloProgress > 0.001) {
      _paintSpiritualHalo(canvas);
    }

    // 1. Sekiz Dilimli Rozet Katmanları (Zümrüt Dış Çerçeve, Altın Halka, Krem İç Madalyon)
    _paintRosetteMedallion(canvas);

    // 2. Kubbe-i Hadra, Altın Alem ve 12 Kemerli Pencere
    _paintGreenDomeAndWindows(canvas);

    // 3. Sağ Üstten Sarkan Tesbih (Doğal Sarkaç Salınımlı)
    _paintPrayerBeads(canvas);

    canvas.restore();
  }

  void _paintSpiritualHalo(Canvas canvas) {
    const center = Offset(_cx, _cy);
    final pulse = math.sin(haloProgress * math.pi);
    final outerRadius = 175.0 + 28.0 * haloProgress + 6.0 * pulse;

    // Radyal altın-zümrüt nur yayılımı
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          haloColor.withValues(alpha: 0.34 * pulse),
          const Color(0xFF236B56).withValues(alpha: 0.16 * pulse),
          haloColor.withValues(alpha: 0.0),
        ],
        stops: const [0.45, 0.78, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: outerRadius));
    canvas.drawCircle(center, outerRadius, glowPaint);

    // Dönen zarif İslami sekizgen yıldız (Rub el Hizb) nur çizgileri
    canvas.save();
    canvas.translate(_cx, _cy);
    canvas.rotate(haloRotation);

    final ringOpacity = (0.28 * pulse).clamp(0.0, 1.0);
    final geoPaint = Paint()
      ..color = haloColor.withValues(alpha: ringOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final starSide = (158.0 + 12.0 * haloProgress) * math.sqrt(2);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: starSide,
      height: starSide,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(14));
    canvas.drawRRect(rrect, geoPaint);
    canvas.rotate(math.pi / 4);
    canvas.drawRRect(rrect, geoPaint);

    // Dış ince altın yörünge halkası
    final orbitPaint = Paint()
      ..color = haloColor.withValues(alpha: ringOpacity * 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    canvas.drawCircle(Offset.zero, 168.0 + 14.0 * haloProgress, orbitPaint);

    canvas.restore();
  }

  Path _buildRosettePath(double rLobe) {
    final sin225 = math.sin(22.5 * math.pi / 180.0);
    final cos225 = math.cos(22.5 * math.pi / 180.0);
    final rCusp = _rc * cos225 +
        math.sqrt(math.max(0.0, rLobe * rLobe - (_rc * sin225) * (_rc * sin225))) -
        0.5;

    Path path = Path()
      ..addOval(Rect.fromCircle(center: const Offset(_cx, _cy), radius: rCusp));

    for (int k = 0; k < 8; k++) {
      final ang = k * (math.pi / 4.0);
      final lx = _cx + _rc * math.cos(ang);
      final ly = _cy + _rc * math.sin(ang);
      final lobePath = Path()
        ..addOval(Rect.fromCircle(center: Offset(lx, ly), radius: rLobe));
      path = Path.combine(PathOperation.union, path, lobePath);
    }
    return path;
  }

  void _paintRosetteMedallion(Canvas canvas) {
    final greenPath = _buildRosettePath(68.5);
    final goldPath = _buildRosettePath(52.0);
    final creamPath = _buildRosettePath(40.0);

    // Rozet yumuşak alt gölgesi
    canvas.drawShadow(
      greenPath,
      Colors.black.withValues(alpha: 0.28),
      10.0,
      false,
    );

    // 1. Dış Koyu Zümrüt Çerçeve (#174D35)
    final greenPaint = Paint()
      ..color = const Color(0xFF174D35)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawPath(greenPath, greenPaint);

    // 2. Orta Altın Çerçeve (#C8A353) + Animasyonlu Işıltı Geçişi
    const goldBounds = Rect.fromLTWH(100, 100, 312, 312);
    final shimmerAngle = (shimmerProgress * 2.0 - 0.5) * math.pi;
    final goldPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(math.cos(shimmerAngle), math.sin(shimmerAngle)),
        end: Alignment(-math.cos(shimmerAngle), -math.sin(shimmerAngle)),
        colors: const [
          Color(0xFFC29C4D),
          Color(0xFFE0BF73),
          Color(0xFFC8A353),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(goldBounds)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawPath(goldPath, goldPaint);

    // 3. İç Sıcak Krem / Parşömen Madalyon (#F1EACA)
    final creamPaint = Paint()
      ..color = const Color(0xFFF1EACA)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawPath(creamPath, creamPaint);
  }

  Path _buildArchedBandPath(
    double xLeft,
    double xRight,
    double yTopEdge,
    double yBotEdge, {
    double archLift = 4.2,
    int steps = 28,
  }) {
    final path = Path();
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final x = xLeft + (xRight - xLeft) * t;
      final lift = archLift * (1.0 - 4.0 * (t - 0.5) * (t - 0.5));
      if (i == 0) {
        path.moveTo(x, yTopEdge - lift);
      } else {
        path.lineTo(x, yTopEdge - lift);
      }
    }
    for (int i = steps; i >= 0; i--) {
      final t = i / steps;
      final x = xLeft + (xRight - xLeft) * t;
      final lift = archLift * (1.0 - 4.0 * (t - 0.5) * (t - 0.5));
      path.lineTo(x, yBotEdge - lift);
    }
    path.close();
    return path;
  }

  void _paintGreenDomeAndWindows(Canvas canvas) {
    // --- A. Altın Alem (Finial) ---
    final goldMain = Paint()
      ..color = const Color(0xFFC59E4F)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final goldLight = Paint()
      ..color = const Color(0xFFDAB562)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final goldDark = Paint()
      ..color = const Color(0xFFA68138)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final spirePath = Path()
      ..moveTo(_dcx, 146.0)
      ..lineTo(_dcx + 1.4, 155.5)
      ..lineTo(_dcx + 2.2, 176.5)
      ..lineTo(_dcx + 10.5, 187.5)
      ..lineTo(_dcx - 10.5, 187.5)
      ..lineTo(_dcx - 2.2, 176.5)
      ..lineTo(_dcx - 1.4, 155.5)
      ..close();
    canvas.drawPath(spirePath, goldMain);

    final pedLeft = Path()
      ..moveTo(_dcx, 176.5)
      ..lineTo(_dcx - 3.8, 177.5)
      ..lineTo(_dcx - 10.5, 187.5)
      ..lineTo(_dcx, 187.5)
      ..close();
    final pedRight = Path()
      ..moveTo(_dcx, 176.5)
      ..lineTo(_dcx + 3.8, 177.5)
      ..lineTo(_dcx + 10.5, 187.5)
      ..lineTo(_dcx, 187.5)
      ..close();
    canvas.drawPath(pedLeft, goldLight);
    canvas.drawPath(pedRight, goldDark);

    const upperSphere = Rect.fromLTRB(_dcx - 3.8, 155.9, _dcx + 3.8, 163.1);
    canvas.drawOval(upperSphere, goldMain);
    canvas.drawArc(upperSphere, math.pi / 2, math.pi, true, goldLight);

    const lowerSphere = Rect.fromLTRB(_dcx - 4.6, 165.1, _dcx + 4.6, 173.9);
    canvas.drawOval(lowerSphere, goldMain);
    canvas.drawArc(lowerSphere, math.pi / 2, math.pi, true, goldLight);

    canvas.drawOval(
      const Rect.fromLTRB(_dcx - 4.2, 175.3, _dcx + 4.2, 178.3),
      goldMain,
    );

    // Alem ucunda sıcak altın ışıltı (Shimmer/Glow)
    final finialGlowAlpha = math.sin(shimmerProgress * math.pi).clamp(0.0, 1.0);
    if (finialGlowAlpha > 0.01) {
      const finialCenter = Offset(_dcx, 158.0);
      final finialGlowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFE599).withValues(alpha: 0.65 * finialGlowAlpha),
            const Color(0xFFD4A574).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: finialCenter, radius: 22.0));
      canvas.drawCircle(finialCenter, 22.0, finialGlowPaint);
    }

    // --- B. Ana Yeşil Kubbe Gövdesi (İki Tonlu) ---
    final leftDomePath = Path()..moveTo(_dcx, 186.5);
    for (final (y, hw) in _domeProfile) {
      leftDomePath.lineTo(_dcx - hw, y);
    }
    leftDomePath
      ..lineTo(_dcx, 272.0)
      ..close();

    final rightDomePath = Path()..moveTo(_dcx, 186.5);
    for (final (y, hw) in _domeProfile) {
      rightDomePath.lineTo(_dcx + hw, y);
    }
    rightDomePath
      ..lineTo(_dcx, 272.0)
      ..close();

    final emeraldLeftPaint = Paint()
      ..color = const Color(0xFF2D683F)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final emeraldRightPaint = Paint()
      ..color = const Color(0xFF154B31)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawPath(leftDomePath, emeraldLeftPaint);
    canvas.drawPath(rightDomePath, emeraldRightPaint);

    // Alem altı koyu kubbe bileziği
    final capPath = Path()
      ..moveTo(_dcx - 9.2, 186.5)
      ..lineTo(_dcx + 9.2, 186.5)
      ..lineTo(_dcx + 12.8, 189.0)
      ..lineTo(_dcx - 12.8, 189.0)
      ..close();
    canvas.drawPath(capPath, Paint()..color = const Color(0xFF0D3724));

    // --- C. Kubbe Eteği ve İki Katlı Silindirik Kaide ---
    final emeraldDarkBand = Paint()
      ..color = const Color(0xFF113F29)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final emeraldMidBand = Paint()
      ..color = const Color(0xFF245A37)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // 1. Korniş kuşağı
    canvas.drawPath(
      _buildArchedBandPath(_dcx - 70.5, _dcx + 70.5, 269.0, 274.0, archLift: 4.0),
      emeraldMidBand,
    );
    canvas.drawPath(
      _buildArchedBandPath(_dcx, _dcx + 70.5, 269.0, 274.0, archLift: 4.0),
      Paint()..color = const Color(0xFF184F32),
    );

    // Koyu boyun kuşağı
    canvas.drawPath(
      _buildArchedBandPath(_dcx - 73.0, _dcx + 73.0, 274.0, 286.0, archLift: 4.2),
      emeraldDarkBand,
    );

    // Üst pencere katı (y=285.5..304)
    canvas.drawPath(
      _buildArchedBandPath(_dcx - 74.2, _dcx + 74.2, 285.5, 304.0, archLift: 4.4),
      emeraldLeftPaint,
    );
    final upperRightShade = Path()
      ..moveTo(_dcx + 25.0, 282.0)
      ..lineTo(_dcx + 74.2, 285.5)
      ..lineTo(_dcx + 74.2, 304.0)
      ..lineTo(_dcx + 25.0, 300.5)
      ..close();
    canvas.drawPath(upperRightShade, Paint()..color = const Color(0xFF1B5435));

    // Orta ayırıcı korniş
    canvas.drawPath(
      _buildArchedBandPath(_dcx - 76.5, _dcx + 76.5, 302.5, 307.0, archLift: 4.5),
      emeraldDarkBand,
    );

    // Alt pencere katı (y=306.5..328.5)
    canvas.drawPath(
      _buildArchedBandPath(_dcx - 76.5, _dcx + 76.5, 306.5, 328.5, archLift: 4.6),
      Paint()..color = const Color(0xFF164C32),
    );

    // Sol ve sağ kademeli payanda çıkıntıları
    final leftButtress = Path()
      ..moveTo(_dcx - 83.0, 310.0)
      ..lineTo(_dcx - 75.5, 309.5)
      ..lineTo(_dcx - 75.5, 329.5)
      ..lineTo(_dcx - 83.0, 330.0)
      ..close();
    final rightButtress = Path()
      ..moveTo(_dcx + 75.5, 309.5)
      ..lineTo(_dcx + 83.0, 310.0)
      ..lineTo(_dcx + 83.0, 330.0)
      ..lineTo(_dcx + 75.5, 329.5)
      ..close();
    canvas.drawPath(leftButtress, Paint()..color = const Color(0xFF14482F));
    canvas.drawPath(rightButtress, emeraldDarkBand);

    // Alt kavisli etek kaidesi
    canvas.drawPath(
      _buildArchedBandPath(_dcx - 88.0, _dcx + 88.0, 326.5, 331.2, archLift: 4.8),
      Paint()..color = const Color(0xFF12442D),
    );

    // --- D. 12 Kemerli Altın Pencere (Canlı Işıltı / Shimmer ile) ---
    for (int i = 0; i < _upperWindows.length; i++) {
      final (wcx, yt, w, h) = _upperWindows[i];
      _drawArchedWindow(canvas, wcx, yt, w, h, i / 6.0);
    }
    for (int i = 0; i < _lowerWindows.length; i++) {
      final (wcx, yt, w, h) = _lowerWindows[i];
      _drawArchedWindow(canvas, wcx, yt, w, h, (i + 0.5) / 6.0);
    }
  }

  void _drawArchedWindow(
    Canvas canvas,
    double wcx,
    double yTop,
    double w,
    double h,
    double phaseOffset,
  ) {
    final r = w / 2.0;
    // Pencere ışıltı dalgası
    final wave = math.sin((shimmerProgress * 1.4 - phaseOffset * 0.45) * math.pi);
    final glowFactor = wave.clamp(0.0, 1.0);

    final winColor = Color.lerp(
      const Color(0xFFCDA856),
      const Color(0xFFFFE494),
      glowFactor * 0.75,
    )!;

    final winPath = Path()
      ..addOval(Rect.fromLTRB(wcx - r, yTop, wcx + r, yTop + w))
      ..addRect(Rect.fromLTRB(wcx - r, yTop + r, wcx + r, yTop + h));

    if (glowFactor > 0.05) {
      final haloPaint = Paint()
        ..color = const Color(0xFFFFDF85).withValues(alpha: 0.35 * glowFactor)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
      canvas.drawPath(winPath, haloPaint);
    }

    canvas.drawPath(
      winPath,
      Paint()
        ..color = winColor
        ..isAntiAlias = true,
    );
  }

  void _paintPrayerBeads(Canvas canvas) {
    // Sağ üst rozet dilimi üzerindeki dayanak noktasından (326, 140) doğal sarkaç salınımı
    const pivotX = 326.0;
    const pivotY = 140.0;

    canvas.save();
    canvas.translate(pivotX, pivotY);
    canvas.rotate(tesbihSwingAngle);
    canvas.translate(-pivotX, -pivotY);

    const beadDarkColor = Color(0xFF442410);
    const beadMidColor = Color(0xFF62371A);
    const beadLightColor = Color(0xFF86522B);

    final darkFill = Paint()
      ..color = beadDarkColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final midFill = Paint()
      ..color = beadMidColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final lightFill = Paint()
      ..color = beadLightColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Rozet kenarını saran üst tesbih bağı
    final strapPath = Path()
      ..moveTo(315.5, 146.0)
      ..lineTo(319.0, 140.0)
      ..lineTo(324.5, 137.8)
      ..lineTo(331.5, 139.5)
      ..lineTo(336.0, 143.0)
      ..lineTo(329.5, 143.2)
      ..lineTo(323.5, 143.8)
      ..lineTo(318.5, 147.8)
      ..close();
    canvas.drawPath(strapPath, darkFill);

    // Tesbih ipi (Sol ve sağ kol)
    final cordPaint = Paint()
      ..color = beadDarkColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final leftCord = Path()
      ..moveTo(316.0, 146.0)
      ..lineTo(310.5, 156.5)
      ..lineTo(308.5, 166.5)
      ..lineTo(308.5, 177.0)
      ..lineTo(309.5, 187.0)
      ..lineTo(312.5, 197.0)
      ..lineTo(317.5, 207.0)
      ..lineTo(323.5, 216.0)
      ..lineTo(330.5, 224.5)
      ..lineTo(338.5, 232.0)
      ..lineTo(348.0, 240.0);
    canvas.drawPath(leftCord, cordPaint);

    final rightCord = Path()
      ..moveTo(371.5, 199.0)
      ..lineTo(371.0, 202.0)
      ..lineTo(370.5, 212.0)
      ..lineTo(367.5, 222.0)
      ..lineTo(361.5, 231.0)
      ..lineTo(354.5, 236.5)
      ..lineTo(348.0, 240.0);
    canvas.drawPath(rightCord, cordPaint);

    void drawBead(double bx, double by, double br) {
      canvas.drawCircle(Offset(bx, by), br, darkFill);
      canvas.drawOval(
        Rect.fromLTRB(
          bx - br * 0.78,
          by - br * 0.78,
          bx + br * 0.65,
          by + br * 0.65,
        ),
        midFill,
      );
      canvas.drawOval(
        Rect.fromLTRB(
          bx - br * 0.45,
          by - br * 0.45,
          bx + br * 0.15,
          by + br * 0.15,
        ),
        lightFill,
      );
    }

    for (final (bx, by, br) in _leftBeads) {
      drawBead(bx, by, br);
    }
    for (final (bx, by, br) in _rightBeads) {
      drawBead(bx, by, br);
    }

    // İmame üstü düğüm habbesi
    drawBead(348.0, 242.5, 5.0);

    // İmame gövdesi
    final imamePath = Path()
      ..moveTo(346.0, 246.5)
      ..lineTo(350.0, 246.5)
      ..lineTo(349.5, 256.5)
      ..lineTo(346.5, 256.5)
      ..close();
    canvas.drawPath(imamePath, midFill);
    drawBead(348.0, 256.8, 2.8);

    // Püskül (Tassel)
    final tasselPath = Path()
      ..moveTo(345.8, 258.5)
      ..lineTo(350.2, 258.5)
      ..lineTo(354.5, 275.5)
      ..lineTo(352.0, 278.5)
      ..lineTo(348.0, 279.2)
      ..lineTo(344.0, 278.5)
      ..lineTo(341.5, 275.5)
      ..close();
    canvas.drawPath(tasselPath, darkFill);

    final threadPaint = Paint()
      ..color = beadMidColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    for (final txOff in const [-2.2, 0.0, 2.2]) {
      canvas.drawLine(
        Offset(348.0 + txOff * 0.4, 260.0),
        Offset(348.0 + txOff, 277.0),
        threadPaint,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ZikirceLogoPainter oldDelegate) {
    return oldDelegate.haloProgress != haloProgress ||
        oldDelegate.haloRotation != haloRotation ||
        oldDelegate.shimmerProgress != shimmerProgress ||
        oldDelegate.tesbihSwingAngle != tesbihSwingAngle ||
        oldDelegate.haloColor != haloColor;
  }
}
