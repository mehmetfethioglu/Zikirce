import 'package:flutter/material.dart';
import '../constants/camera_colors.dart';

/// Rule-of-thirds grid, corner brackets, and 4-point perspective warp quad overlay.
class ViewfinderGridAndPerspectivePainter extends CustomPainter {
  const ViewfinderGridAndPerspectivePainter({
    required this.showPerspectiveQuad,
    required this.warpActive,
    required this.corners,
  });

  final bool showPerspectiveQuad;
  final bool warpActive;
  final List<Offset> corners;

  @override
  void paint(Canvas canvas, Size size) {
    const topFrameY = 52.0;
    final bottomFrameY =
        (size.height - 135.0).clamp(topFrameY + 100.0, size.height);
    const padX = 2.0;
    const len = 18.0;

    final frameH = bottomFrameY - topFrameY;
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.11)
      ..strokeWidth = 0.6;
    canvas.drawLine(
      Offset(size.width / 3, topFrameY),
      Offset(size.width / 3, bottomFrameY),
      gridPaint,
    );
    canvas.drawLine(
      Offset(size.width * 2 / 3, topFrameY),
      Offset(size.width * 2 / 3, bottomFrameY),
      gridPaint,
    );
    canvas.drawLine(
      Offset(0, topFrameY + frameH / 3),
      Offset(size.width, topFrameY + frameH / 3),
      gridPaint,
    );
    canvas.drawLine(
      Offset(0, topFrameY + frameH * 2 / 3),
      Offset(size.width, topFrameY + frameH * 2 / 3),
      gridPaint,
    );

    final bracketPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.65)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(padX, topFrameY + len)
        ..lineTo(padX, topFrameY)
        ..lineTo(padX + len, topFrameY),
      bracketPaint,
    );
    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - padX - len, topFrameY)
        ..lineTo(size.width - padX, topFrameY)
        ..lineTo(size.width - padX, topFrameY + len),
      bracketPaint,
    );
    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(padX, bottomFrameY - len)
        ..lineTo(padX, bottomFrameY)
        ..lineTo(padX + len, bottomFrameY),
      bracketPaint,
    );
    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - padX - len, bottomFrameY)
        ..lineTo(size.width - padX, bottomFrameY)
        ..lineTo(size.width - padX, bottomFrameY - len),
      bracketPaint,
    );

    if (!showPerspectiveQuad || corners.length < 4) return;

    final pts = [
      for (final c in corners) Offset(c.dx * size.width, c.dy * size.height),
    ];
    final path = Path()
      ..moveTo(pts[0].dx, pts[0].dy)
      ..lineTo(pts[1].dx, pts[1].dy)
      ..lineTo(pts[2].dx, pts[2].dy)
      ..lineTo(pts[3].dx, pts[3].dy)
      ..close();

    final borderPaint = Paint()
      ..color = warpActive
          ? kZameraCyan.withValues(alpha: 0.9)
          : kIosYellow.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawPath(path, borderPaint);

    final handlePaint = Paint()
      ..color = kIosYellow
      ..style = PaintingStyle.fill;
    for (final pt in pts) {
      canvas.drawCircle(pt, 6.0, handlePaint);
    }
  }

  @override
  bool shouldRepaint(
    covariant ViewfinderGridAndPerspectivePainter oldDelegate,
  ) =>
      oldDelegate.showPerspectiveQuad != showPerspectiveQuad ||
      oldDelegate.warpActive != warpActive ||
      oldDelegate.corners != corners;
}
