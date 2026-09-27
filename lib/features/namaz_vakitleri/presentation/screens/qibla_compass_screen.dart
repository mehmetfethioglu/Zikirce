import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/services/prayer_times_service.dart';
import '../../../../core/services/haptic_service.dart';

class QiblaCompassScreen extends StatefulWidget {
  final double userLat;
  final double userLng;

  const QiblaCompassScreen({
    super.key,
    this.userLat = 41.0082, // Istanbul default
    this.userLng = 28.9784,
  });

  @override
  State<QiblaCompassScreen> createState() => _QiblaCompassScreenState();
}

class _QiblaCompassScreenState extends State<QiblaCompassScreen> {
  StreamSubscription<MagnetometerEvent>? _magnetoSub;
  double _heading = 0.0;
  late double _qiblaAngle;
  bool _isAligned = false;

  @override
  void initState() {
    super.initState();
    _qiblaAngle = PrayerTimesService.calculateQiblaDirection(widget.userLat, widget.userLng);

    _magnetoSub = magnetometerEventStream().listen((event) {
      // Calculate heading angle in degrees from magnetometer vector
      double heading = math.atan2(event.y, event.x) * (180 / math.pi);
      if (heading < 0) heading += 360;

      final diff = (heading - _qiblaAngle).abs();
      final aligned = diff < 5.0 || diff > 355.0;

      if (aligned && !_isAligned) {
        HapticService.targetReached();
      }

      setState(() {
        _heading = heading;
        _isAligned = aligned;
      });
    });
  }

  @override
  void dispose() {
    _magnetoSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final needleRotation = (_qiblaAngle - _heading) * (math.pi / 180);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        title: Text('Kıble Pusulası', style: AppTypography.headingSmall(color: Colors.white)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Status Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: _isAligned ? AppColors.emerald500.withValues(alpha: 0.2) : AppColors.darkCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isAligned ? AppColors.emerald400 : AppColors.darkBorder,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isAligned ? Icons.check_circle_rounded : Icons.explore_rounded,
                    color: _isAligned ? AppColors.emerald400 : AppColors.gold400,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _isAligned ? 'Kıbleye Yöneldiniz!' : 'Kıble Açısı: ${_qiblaAngle.toStringAsFixed(0)}°',
                    style: TextStyle(
                      color: _isAligned ? AppColors.emerald400 : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            // Compass Dial with Rotating Kaaba Pointer
            SizedBox(
              width: 280,
              height: 280,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Compass Ring
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.darkCard,
                      border: Border.all(
                        color: _isAligned ? AppColors.emerald400 : AppColors.gold500.withValues(alpha: 0.4),
                        width: 3.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _isAligned
                              ? AppColors.emerald500.withValues(alpha: 0.3)
                              : AppColors.gold500.withValues(alpha: 0.15),
                          blurRadius: 28,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  // Rotating Needle pointing to Kaaba
                  Transform.rotate(
                    angle: needleRotation,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Kaaba Icon at top of needle
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black,
                          ),
                          child: const Icon(
                            Icons.mosque_rounded,
                            color: AppColors.gold400,
                            size: 32,
                          ),
                        ),
                        Container(
                          width: 4,
                          height: 90,
                          decoration: BoxDecoration(
                            gradient: AppColors.goldGradient,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Center Pivot
                  Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.gold500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            const Text(
              'Cihazınızı düz bir zeminde tutunuz.',
              style: TextStyle(color: Color(0xFF8A9BAE), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
