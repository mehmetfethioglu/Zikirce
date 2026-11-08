import 'package:flutter/material.dart';

/// Active radial dial selector for Pro Photo, Art Mode, Portrait, and Pro Video.
enum ActiveProDial {
  none,
  lens,
  aperture,
  portraitLight,
  ev,
  iso,
  shutter,
  shutterAngle,
  videoFps,
  videoProfile,
  videoLut,
  videoAudio,
  wb,
  focus;

  String get labelTr {
    switch (this) {
      case ActiveProDial.none:
        return '';
      case ActiveProDial.lens:
        return 'LENS';
      case ActiveProDial.aperture:
        return 'DİYAFRAM';
      case ActiveProDial.portraitLight:
        return 'IŞIK';
      case ActiveProDial.ev:
        return 'EV';
      case ActiveProDial.iso:
        return 'ISO';
      case ActiveProDial.shutter:
        return 'ENSTANTANE';
      case ActiveProDial.shutterAngle:
        return 'AÇI (180°)';
      case ActiveProDial.videoFps:
        return 'FPS';
      case ActiveProDial.videoProfile:
        return 'PROFİL';
      case ActiveProDial.videoLut:
        return 'LUT';
      case ActiveProDial.videoAudio:
        return 'SES';
      case ActiveProDial.wb:
        return 'WB';
      case ActiveProDial.focus:
        return 'ODAK';
    }
  }

  IconData get icon {
    switch (this) {
      case ActiveProDial.none:
        return Icons.circle_outlined;
      case ActiveProDial.lens:
        return Icons.camera_alt;
      case ActiveProDial.aperture:
        return Icons.camera;
      case ActiveProDial.portraitLight:
        return Icons.wb_incandescent;
      case ActiveProDial.ev:
        return Icons.exposure;
      case ActiveProDial.iso:
        return Icons.iso;
      case ActiveProDial.shutter:
        return Icons.shutter_speed;
      case ActiveProDial.shutterAngle:
        return Icons.rotate_right;
      case ActiveProDial.videoFps:
        return Icons.speed;
      case ActiveProDial.videoProfile:
        return Icons.palette;
      case ActiveProDial.videoLut:
        return Icons.filter_vintage;
      case ActiveProDial.videoAudio:
        return Icons.mic;
      case ActiveProDial.wb:
        return Icons.wb_sunny;
      case ActiveProDial.focus:
        return Icons.center_focus_strong;
    }
  }
}
