import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/camera_colors.dart';

/// Color / gamma profile option for Pro Cinema Video HUD.
class CinemaProfileOption {
  final String id;
  final String shortLabel;
  final bool isTenBit;

  const CinemaProfileOption({
    required this.id,
    required this.shortLabel,
    required this.isTenBit,
  });

  static const List<CinemaProfileOption> defaultOptions = <CinemaProfileOption>[
    CinemaProfileOption(id: 'rec709', shortLabel: 'REC.709', isTenBit: false),
    CinemaProfileOption(id: 'clog', shortLabel: 'Z-LOG', isTenBit: true),
    CinemaProfileOption(id: 'hlg10', shortLabel: 'HLG 10', isTenBit: true),
  ];
}

/// Optical lens descriptor for VideoCinemaQuickDeck.
class CinemaLensOption {
  final String id;
  final String label;

  const CinemaLensOption({
    required this.id,
    required this.label,
  });

  static const List<CinemaLensOption> defaultOptions = <CinemaLensOption>[
    CinemaLensOption(id: '0.6', label: '0.6x'),
    CinemaLensOption(id: '1.0', label: '1x'),
    CinemaLensOption(id: '2.0', label: '2x'),
  ];
}

/// Interactive top Cinema HUD with STBY/REC + SMPTE timecode, clickable
/// Resolution / FPS / 180° Shutter / Profile / LUT (+ LUT BYPASS) pills,
/// broadcast [-60..-12..-6..0 dB] Peak+RMS dBFS meter, and thermal/ND telemetry.
class ProVideoCinemaHud extends StatelessWidget {
  final bool isRecording;
  final String timecode;
  final String resolutionLabel;
  final int fps;
  final List<int> fpsOptions;
  final bool isFpsSelectorOpen;
  final String shutterAngleLabel;
  final String shutterSpeedLabel;
  final bool isShutterLocked;
  final String activeProfileId;
  final String? profileLabel;
  final bool? isTenBitOverride;
  final List<CinemaProfileOption> profileOptions;
  final bool isProfileSelectorOpen;
  final String? lutLabel;
  final bool isLutEnabled;
  final bool isLutBypassed;
  final double audioRmsDb;
  final double audioPeakDb;
  final String thermalLabel;
  final bool isThermalWarning;
  final int? remainingMinutes;
  final int droppedFrames;
  final bool ndFilterWarning;

  final VoidCallback? onCycleResolution;
  final VoidCallback? onTapFps;
  final ValueChanged<int>? onSelectFps;
  final VoidCallback? onTapShutterAngle;
  final VoidCallback? onToggleShutterLock;
  final VoidCallback? onTapProfile;
  final ValueChanged<String>? onSelectProfile;
  final VoidCallback? onTapLut;
  final VoidCallback? onToggleLutBypass;

  const ProVideoCinemaHud({
    super.key,
    this.isRecording = false,
    this.timecode = '00:00:00:00',
    this.resolutionLabel = '4K',
    this.fps = 24,
    this.fpsOptions = const <int>[24, 30, 60],
    this.isFpsSelectorOpen = false,
    this.shutterAngleLabel = '180°',
    this.shutterSpeedLabel = '1/48s',
    this.isShutterLocked = true,
    this.activeProfileId = 'rec709',
    this.profileLabel,
    this.isTenBitOverride,
    this.profileOptions = CinemaProfileOption.defaultOptions,
    this.isProfileSelectorOpen = false,
    this.lutLabel,
    this.isLutEnabled = false,
    this.isLutBypassed = false,
    this.audioRmsDb = -60.0,
    this.audioPeakDb = -60.0,
    this.thermalLabel = 'NOMİNAL',
    this.isThermalWarning = false,
    this.remainingMinutes,
    this.droppedFrames = 0,
    this.ndFilterWarning = false,
    this.onCycleResolution,
    this.onTapFps,
    this.onSelectFps,
    this.onTapShutterAngle,
    this.onToggleShutterLock,
    this.onTapProfile,
    this.onSelectProfile,
    this.onTapLut,
    this.onToggleLutBypass,
  });

  CinemaProfileOption _resolveActiveProfile() {
    for (final CinemaProfileOption opt in profileOptions) {
      if (opt.id == activeProfileId) return opt;
    }
    if (profileOptions.isNotEmpty) return profileOptions.first;
    return const CinemaProfileOption(
      id: 'rec709',
      shortLabel: 'REC.709',
      isTenBit: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final CinemaProfileOption resolvedProfile = _resolveActiveProfile();
    final String effectiveProfileText =
        profileLabel ?? resolvedProfile.shortLabel;
    final bool effectiveTenBit = isTenBitOverride ?? resolvedProfile.isTenBit;

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: kSurfaceDark.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRecording
                ? const Color(0xFFFF3B30).withValues(alpha: 0.65)
                : kBorderDark,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _CinemaHeaderRow(
              isRecording: isRecording,
              timecode: timecode,
              thermalLabel: thermalLabel,
              isThermalWarning: isThermalWarning,
              remainingMinutes: remainingMinutes,
              droppedFrames: droppedFrames,
            ),
            const SizedBox(height: 6),
            _CinemaInteractivePillsStrip(
              resolutionLabel: resolutionLabel,
              fps: fps,
              fpsOptions: fpsOptions,
              shutterAngleLabel: shutterAngleLabel,
              shutterSpeedLabel: shutterSpeedLabel,
              isShutterLocked: isShutterLocked,
              profileText: effectiveProfileText,
              isTenBit: effectiveTenBit,
              activeProfileId: activeProfileId,
              profileOptions: profileOptions,
              lutLabel: lutLabel,
              isLutEnabled: isLutEnabled,
              isLutBypassed: isLutBypassed,
              onCycleResolution: onCycleResolution,
              onTapFps: onTapFps,
              onSelectFps: onSelectFps,
              onTapShutterAngle: onTapShutterAngle,
              onToggleShutterLock: onToggleShutterLock,
              onTapProfile: onTapProfile,
              onSelectProfile: onSelectProfile,
              onTapLut: onTapLut,
              onToggleLutBypass: onToggleLutBypass,
            ),
            if (isFpsSelectorOpen && fpsOptions.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              _CinemaFpsSelectorTray(
                activeFps: fps,
                fpsOptions: fpsOptions,
                onSelectFps: onSelectFps,
              ),
            ],
            if (isProfileSelectorOpen && profileOptions.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              _CinemaProfileSelectorTray(
                activeProfileId: activeProfileId,
                profileOptions: profileOptions,
                onSelectProfile: onSelectProfile,
              ),
            ],
            const SizedBox(height: 6),
            _BroadcastDbMeterRow(
              rmsDb: audioRmsDb,
              peakDb: audioPeakDb,
              ndFilterWarning: ndFilterWarning,
              isLutBypassed: isLutBypassed,
            ),
          ],
        ),
      ),
    );
  }
}

class _CinemaHeaderRow extends StatelessWidget {
  final bool isRecording;
  final String timecode;
  final String thermalLabel;
  final bool isThermalWarning;
  final int? remainingMinutes;
  final int droppedFrames;

  const _CinemaHeaderRow({
    required this.isRecording,
    required this.timecode,
    required this.thermalLabel,
    required this.isThermalWarning,
    required this.remainingMinutes,
    required this.droppedFrames,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _CinemaRecStatusBadge(
          isRecording: isRecording,
          timecode: timecode,
        ),
        const Spacer(),
        if (droppedFrames > 0) ...<Widget>[
          _CinemaMicroTag(
            label: 'DROP $droppedFrames',
            color: const Color(0xFFFF453A),
            filled: true,
          ),
          const SizedBox(width: 5),
        ],
        if (remainingMinutes != null) ...<Widget>[
          _CinemaMicroTag(
            label: '${remainingMinutes}DK',
            color: remainingMinutes! <= 5
                ? const Color(0xFFFF9F0A)
                : const Color(0xFF9EA5B8),
            filled: false,
          ),
          const SizedBox(width: 5),
        ],
        _CinemaMicroTag(
          label: thermalLabel,
          color: isThermalWarning ? const Color(0xFFFF453A) : kZameraCyan,
          filled: isThermalWarning,
        ),
      ],
    );
  }
}

class _CinemaRecStatusBadge extends StatelessWidget {
  final bool isRecording;
  final String timecode;

  const _CinemaRecStatusBadge({
    required this.isRecording,
    required this.timecode,
  });

  @override
  Widget build(BuildContext context) {
    final Color badgeColor = isRecording
        ? const Color(0xFFFF3B30)
        : const Color(0xFF676E82);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isRecording
            ? badgeColor.withValues(alpha: 0.24)
            : kObsidianBg.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeColor, width: 0.9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6.5,
            height: 6.5,
            decoration: BoxDecoration(
              color: isRecording ? badgeColor : kZameraCyan,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isRecording ? 'REC  $timecode' : 'STBY $timecode',
            style: TextStyle(
              color: isRecording ? const Color(0xFFFF6961) : Colors.white,
              fontSize: 11,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _CinemaMicroTag extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;

  const _CinemaMicroTag({
    required this.label,
    required this.color,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2),
      decoration: BoxDecoration(
        color: filled
            ? color.withValues(alpha: 0.2)
            : kObsidianBg.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: filled ? color : kBorderDark,
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _CinemaInteractivePillsStrip extends StatelessWidget {
  final String resolutionLabel;
  final int fps;
  final List<int> fpsOptions;
  final String shutterAngleLabel;
  final String shutterSpeedLabel;
  final bool isShutterLocked;
  final String profileText;
  final bool isTenBit;
  final String activeProfileId;
  final List<CinemaProfileOption> profileOptions;
  final String? lutLabel;
  final bool isLutEnabled;
  final bool isLutBypassed;

  final VoidCallback? onCycleResolution;
  final VoidCallback? onTapFps;
  final ValueChanged<int>? onSelectFps;
  final VoidCallback? onTapShutterAngle;
  final VoidCallback? onToggleShutterLock;
  final VoidCallback? onTapProfile;
  final ValueChanged<String>? onSelectProfile;
  final VoidCallback? onTapLut;
  final VoidCallback? onToggleLutBypass;

  const _CinemaInteractivePillsStrip({
    required this.resolutionLabel,
    required this.fps,
    required this.fpsOptions,
    required this.shutterAngleLabel,
    required this.shutterSpeedLabel,
    required this.isShutterLocked,
    required this.profileText,
    required this.isTenBit,
    required this.activeProfileId,
    required this.profileOptions,
    required this.lutLabel,
    required this.isLutEnabled,
    required this.isLutBypassed,
    required this.onCycleResolution,
    required this.onTapFps,
    required this.onSelectFps,
    required this.onTapShutterAngle,
    required this.onToggleShutterLock,
    required this.onTapProfile,
    required this.onSelectProfile,
    required this.onTapLut,
    required this.onToggleLutBypass,
  });

  void _handleFpsTap() {
    if (onTapFps != null) {
      onTapFps!();
      return;
    }
    if (onSelectFps != null && fpsOptions.isNotEmpty) {
      final int idx = fpsOptions.indexOf(fps);
      final int next = fpsOptions[(idx + 1) % fpsOptions.length];
      onSelectFps!(next);
    }
  }

  void _handleProfileTap() {
    if (onTapProfile != null) {
      onTapProfile!();
      return;
    }
    if (onSelectProfile != null && profileOptions.isNotEmpty) {
      final int idx = profileOptions.indexWhere(
        (CinemaProfileOption e) => e.id == activeProfileId,
      );
      final CinemaProfileOption next =
          profileOptions[(idx + 1) % profileOptions.length];
      onSelectProfile!(next.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canTapFps =
        onTapFps != null || (onSelectFps != null && fpsOptions.isNotEmpty);
    final bool canTapProfile =
        onTapProfile != null ||
        (onSelectProfile != null && profileOptions.isNotEmpty);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: <Widget>[
          _CinemaHudActionPill(
            label: resolutionLabel,
            accentColor: kIosYellow,
            isHighlighted: resolutionLabel.toUpperCase().contains('4K'),
            onTap: onCycleResolution,
          ),
          const SizedBox(width: 5),
          _CinemaHudActionPill(
            label: '${fps}FPS',
            accentColor: kZameraCyan,
            isHighlighted: false,
            onTap: canTapFps ? _handleFpsTap : null,
          ),
          const SizedBox(width: 5),
          _CinemaShutterAnglePill(
            shutterAngleLabel: shutterAngleLabel,
            shutterSpeedLabel: shutterSpeedLabel,
            isShutterLocked: isShutterLocked,
            onTapShutterAngle: onTapShutterAngle,
            onToggleShutterLock: onToggleShutterLock,
          ),
          const SizedBox(width: 5),
          _CinemaProfilePill(
            profileText: profileText,
            isTenBit: isTenBit,
            onTap: canTapProfile ? _handleProfileTap : null,
          ),
          const SizedBox(width: 5),
          _CinemaLutPill(
            lutLabel: lutLabel,
            isLutEnabled: isLutEnabled,
            isLutBypassed: isLutBypassed,
            onTapLut: onTapLut,
            onToggleLutBypass: onToggleLutBypass,
          ),
        ],
      ),
    );
  }
}

class _CinemaHudActionPill extends StatelessWidget {
  final String label;
  final Color accentColor;
  final bool isHighlighted;
  final VoidCallback? onTap;

  const _CinemaHudActionPill({
    required this.label,
    required this.accentColor,
    required this.isHighlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
        decoration: BoxDecoration(
          color: isHighlighted
              ? accentColor.withValues(alpha: 0.16)
              : kCardDark,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: isHighlighted
                ? accentColor.withValues(alpha: 0.75)
                : kBorderDark,
            width: 0.9,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isHighlighted ? accentColor : Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

class _CinemaShutterAnglePill extends StatelessWidget {
  final String shutterAngleLabel;
  final String shutterSpeedLabel;
  final bool isShutterLocked;
  final VoidCallback? onTapShutterAngle;
  final VoidCallback? onToggleShutterLock;

  const _CinemaShutterAnglePill({
    required this.shutterAngleLabel,
    required this.shutterSpeedLabel,
    required this.isShutterLocked,
    required this.onTapShutterAngle,
    required this.onToggleShutterLock,
  });

  @override
  Widget build(BuildContext context) {
    final String combined = shutterSpeedLabel.isEmpty
        ? shutterAngleLabel
        : '$shutterAngleLabel · $shutterSpeedLabel';
    final Color borderColor = isShutterLocked
        ? kIosYellow.withValues(alpha: 0.65)
        : kBorderDark;

    return Container(
      decoration: BoxDecoration(
        color: kCardDark,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: borderColor, width: 0.9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTapShutterAngle ?? onToggleShutterLock,
            onLongPress: onToggleShutterLock,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4.5),
              child: Text(
                combined,
                style: TextStyle(
                  color: isShutterLocked ? kIosYellow : Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ),
          ),
          if (onToggleShutterLock != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggleShutterLock,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 4.5,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: kBorderDark, width: 0.8),
                  ),
                ),
                child: Icon(
                  isShutterLocked
                      ? Icons.lock_rounded
                      : Icons.lock_open_rounded,
                  size: 11,
                  color: isShutterLocked ? kIosYellow : Colors.white54,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CinemaProfilePill extends StatelessWidget {
  final String profileText;
  final bool isTenBit;
  final VoidCallback? onTap;

  const _CinemaProfilePill({
    required this.profileText,
    required this.isTenBit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7.5, vertical: 4.5),
        decoration: BoxDecoration(
          color: isTenBit
              ? kZameraCyan.withValues(alpha: 0.14)
              : kCardDark,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: isTenBit
                ? kZameraCyan.withValues(alpha: 0.7)
                : kBorderDark,
            width: 0.9,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              profileText,
              style: TextStyle(
                color: isTenBit ? kZameraCyan : Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (isTenBit) ...<Widget>[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 3.5,
                  vertical: 0.5,
                ),
                decoration: BoxDecoration(
                  color: kZameraCyan.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(3.5),
                ),
                child: const Text(
                  '10B',
                  style: TextStyle(
                    color: kZameraCyan,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CinemaLutPill extends StatelessWidget {
  final String? lutLabel;
  final bool isLutEnabled;
  final bool isLutBypassed;
  final VoidCallback? onTapLut;
  final VoidCallback? onToggleLutBypass;

  const _CinemaLutPill({
    required this.lutLabel,
    required this.isLutEnabled,
    required this.isLutBypassed,
    required this.onTapLut,
    required this.onToggleLutBypass,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasLut =
        isLutEnabled || (lutLabel != null && lutLabel!.trim().isNotEmpty);
    final String display = isLutBypassed
        ? 'LUT BYPASS'
        : (hasLut ? 'LUT: ${lutLabel ?? "AKTİF"}' : 'LUT YOK');

    final Color borderColor = isLutBypassed
        ? const Color(0xFFFF9F0A)
        : (hasLut ? kIosYellow.withValues(alpha: 0.65) : kBorderDark);

    return Container(
      decoration: BoxDecoration(
        color: isLutBypassed
            ? const Color(0xFFFF9F0A).withValues(alpha: 0.2)
            : kCardDark,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: borderColor, width: 0.9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTapLut,
            onLongPress: onToggleLutBypass,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7.5, vertical: 4.5),
              child: Text(
                display,
                style: TextStyle(
                  color: isLutBypassed
                      ? const Color(0xFFFF9F0A)
                      : (hasLut ? kIosYellow : Colors.white70),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          if (onToggleLutBypass != null && (hasLut || isLutBypassed))
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggleLutBypass,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5.5,
                  vertical: 4.5,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: kBorderDark, width: 0.8),
                  ),
                ),
                child: Icon(
                  isLutBypassed
                      ? Icons.visibility_off_rounded
                      : Icons.compare_rounded,
                  size: 11.5,
                  color: isLutBypassed
                      ? const Color(0xFFFF9F0A)
                      : Colors.white70,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CinemaFpsSelectorTray extends StatelessWidget {
  final int activeFps;
  final List<int> fpsOptions;
  final ValueChanged<int>? onSelectFps;

  const _CinemaFpsSelectorTray({
    required this.activeFps,
    required this.fpsOptions,
    required this.onSelectFps,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Text(
          'KARE HIZI',
          style: TextStyle(
            color: Color(0xFF8E95A8),
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            spacing: 5,
            runSpacing: 4,
            children: <Widget>[
              for (final int option in fpsOptions)
                _CinemaSubOptionChip(
                  label: '${option}p',
                  isSelected: option == activeFps,
                  onTap: onSelectFps != null ? () => onSelectFps!(option) : null,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CinemaProfileSelectorTray extends StatelessWidget {
  final String activeProfileId;
  final List<CinemaProfileOption> profileOptions;
  final ValueChanged<String>? onSelectProfile;

  const _CinemaProfileSelectorTray({
    required this.activeProfileId,
    required this.profileOptions,
    required this.onSelectProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Text(
          'PROFİL',
          style: TextStyle(
            color: Color(0xFF8E95A8),
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            spacing: 5,
            runSpacing: 4,
            children: <Widget>[
              for (final CinemaProfileOption opt in profileOptions)
                _CinemaSubOptionChip(
                  label: opt.isTenBit
                      ? '${opt.shortLabel} 10B'
                      : opt.shortLabel,
                  isSelected: opt.id == activeProfileId,
                  onTap: onSelectProfile != null
                      ? () => onSelectProfile!(opt.id)
                      : null,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CinemaSubOptionChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  const _CinemaSubOptionChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? kIosYellow : kObsidianBg.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: isSelected ? kIosYellow : kBorderDark,
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? kObsidianBg : Colors.white70,
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _BroadcastDbMeterRow extends StatelessWidget {
  final double rmsDb;
  final double peakDb;
  final bool ndFilterWarning;
  final bool isLutBypassed;

  const _BroadcastDbMeterRow({
    required this.rmsDb,
    required this.peakDb,
    required this.ndFilterWarning,
    required this.isLutBypassed,
  });

  @override
  Widget build(BuildContext context) {
    final double clampedPeak = peakDb.clamp(-60.0, 0.0);
    final bool isClipping = clampedPeak >= -0.8;

    return Row(
      children: <Widget>[
        Icon(
          Icons.graphic_eq_rounded,
          size: 12,
          color: isClipping ? const Color(0xFFFF453A) : const Color(0xFF9EA5B8),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: SizedBox(
            height: 18,
            child: CustomPaint(
              painter: _BroadcastDbMeterPainter(
                rmsDb: rmsDb.clamp(-60.0, 0.0),
                peakDb: clampedPeak,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${clampedPeak.round()}dB',
          style: TextStyle(
            color: isClipping
                ? const Color(0xFFFF453A)
                : const Color(0xFF9EA5B8),
            fontSize: 9,
            fontWeight: FontWeight.w800,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
        if (ndFilterWarning) ...<Widget>[
          const SizedBox(width: 6),
          const _CinemaMicroTag(
            label: 'ND GEREKLİ',
            color: Color(0xFFFF9F0A),
            filled: true,
          ),
        ] else if (isLutBypassed) ...<Widget>[
          const SizedBox(width: 6),
          const _CinemaMicroTag(
            label: 'HAM LOG',
            color: Color(0xFFFF9F0A),
            filled: true,
          ),
        ],
      ],
    );
  }
}

class _BroadcastDbMeterPainter extends CustomPainter {
  final double rmsDb;
  final double peakDb;

  const _BroadcastDbMeterPainter({
    required this.rmsDb,
    required this.peakDb,
  });

  static double _dbToNorm(double db) => ((db + 60.0) / 60.0).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    const double barTop = 1.5;
    const double barHeight = 5.5;
    final double w = size.width;
    if (w <= 0) return;

    final RRect trackRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, barTop, w, barHeight),
      const Radius.circular(2.5),
    );
    canvas.drawRRect(trackRect, Paint()..color = const Color(0xFF1A1D28));

    final double rmsNorm = _dbToNorm(rmsDb);
    final double greenEnd = _dbToNorm(-12.0);
    final double yellowEnd = _dbToNorm(-6.0);

    canvas.save();
    canvas.clipRRect(trackRect);

    // Zone 1: -60..-12 dB (Broadcast Nominal Green)
    final double gNorm = rmsNorm.clamp(0.0, greenEnd);
    if (gNorm > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, barTop, w * gNorm, barHeight),
        Paint()..color = const Color(0xFF30D158),
      );
    }

    // Zone 2: -12..-6 dB (Headroom Yellow)
    if (rmsNorm > greenEnd) {
      final double yNorm = rmsNorm.clamp(greenEnd, yellowEnd);
      canvas.drawRect(
        Rect.fromLTWH(w * greenEnd, barTop, w * (yNorm - greenEnd), barHeight),
        Paint()..color = kIosYellow,
      );
    }

    // Zone 3: -6..0 dB (Peak Warning Red)
    if (rmsNorm > yellowEnd) {
      canvas.drawRect(
        Rect.fromLTWH(w * yellowEnd, barTop, w * (rmsNorm - yellowEnd), barHeight),
        Paint()..color = const Color(0xFFFF3B30),
      );
    }

    canvas.restore();

    // Peak hold razor indicator
    final double peakX = (w * _dbToNorm(peakDb)).clamp(1.0, w - 1.0);
    final Color peakColor = peakDb >= -6.0
        ? const Color(0xFFFF453A)
        : (peakDb >= -12.0 ? kIosYellow : Colors.white);
    canvas.drawLine(
      Offset(peakX, 0.5),
      Offset(peakX, barTop + barHeight + 1.0),
      Paint()
        ..color = peakColor
        ..strokeWidth = 1.8,
    );

    // Scale labels: -60, -12, -6, 0 dB
    const List<int> scaleMarks = <int>[-60, -12, -6, 0];
    for (final int dbMark in scaleMarks) {
      final double markX = w * _dbToNorm(dbMark.toDouble());
      final String txt = '$dbMark';
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: txt,
          style: TextStyle(
            color: dbMark == 0
                ? const Color(0xFFFF6961)
                : const Color(0xFF7D8498),
            fontSize: 7.5,
            fontWeight: FontWeight.w700,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final double dx = (markX - tp.width * 0.5).clamp(0.0, w - tp.width);
      tp.paint(canvas, Offset(dx, barTop + barHeight + 1.5));
    }
  }

  @override
  bool shouldRepaint(covariant _BroadcastDbMeterPainter oldDelegate) {
    return oldDelegate.rmsDb != rmsDb || oldDelegate.peakDb != peakDb;
  }
}

/// Curved concentric radial Cinema Quick Deck usable live during recording:
/// Optical lens nodes, A · B · A↔B Rack Focus + speed node, EIS, and AEL lock
/// arranged along a rising circular arc guide above the shutter.
class VideoCinemaQuickDeck extends StatelessWidget {
  final List<CinemaLensOption> lensOptions;
  final String activeLensId;
  final ValueChanged<String>? onSelectLens;

  final int rackDurationMs;
  final bool hasPointA;
  final bool hasPointB;
  final bool isRackActive;
  final VoidCallback? onSetPointA;
  final VoidCallback? onSetPointB;
  final VoidCallback? onTriggerRackAB;
  final VoidCallback? onCycleRackDuration;

  final bool eisEnabled;
  final VoidCallback? onToggleEis;

  final bool aeAfLocked;
  final VoidCallback? onToggleAeAfLock;

  const VideoCinemaQuickDeck({
    super.key,
    this.lensOptions = CinemaLensOption.defaultOptions,
    this.activeLensId = '1.0',
    this.onSelectLens,
    this.rackDurationMs = 2000,
    this.hasPointA = false,
    this.hasPointB = false,
    this.isRackActive = false,
    this.onSetPointA,
    this.onSetPointB,
    this.onTriggerRackAB,
    this.onCycleRackDuration,
    this.eisEnabled = true,
    this.onToggleEis,
    this.aeAfLocked = false,
    this.onToggleAeAfLock,
  });

  List<_CinemaArcDeckEntry> _collectEntries() {
    final String speedLabel =
        '${(rackDurationMs / 1000.0).toStringAsFixed(1)}s';
    return <_CinemaArcDeckEntry>[
      for (final CinemaLensOption lens in lensOptions)
        _CinemaArcDeckEntry(
          label: lens.label,
          isActive: lens.id == activeLensId,
          accentColor: kIosYellow,
          filledWhenActive: true,
          weight: 1.02,
          onTap: onSelectLens != null ? () => onSelectLens!(lens.id) : null,
        ),
      _CinemaArcDeckEntry(
        label: 'A',
        isActive: hasPointA,
        accentColor: kIosYellow,
        filledWhenActive: false,
        weight: 0.86,
        separatorBefore: lensOptions.isNotEmpty,
        onTap: onSetPointA,
      ),
      _CinemaArcDeckEntry(
        label: 'B',
        isActive: hasPointB,
        accentColor: kIosYellow,
        filledWhenActive: false,
        weight: 0.86,
        onTap: onSetPointB,
      ),
      _CinemaArcDeckEntry(
        label: 'A↔B',
        isActive: true,
        accentColor: isRackActive ? kIosYellow : kZameraCyan,
        filledWhenActive: isRackActive,
        weight: 1.20,
        onTap: onTriggerRackAB,
      ),
      _CinemaArcDeckEntry(
        label: speedLabel,
        isActive: false,
        accentColor: Colors.white70,
        filledWhenActive: false,
        weight: 1.10,
        onTap: onCycleRackDuration,
      ),
      _CinemaArcDeckEntry(
        label: 'EIS',
        isActive: eisEnabled,
        accentColor: kZameraCyan,
        filledWhenActive: false,
        weight: 1.04,
        separatorBefore: true,
        onTap: onToggleEis,
      ),
      _CinemaArcDeckEntry(
        label: 'AEL',
        isActive: aeAfLocked,
        accentColor: kIosYellow,
        filledWhenActive: aeAfLocked,
        icon: aeAfLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
        weight: 1.24,
        onTap: onToggleAeAfLock,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final List<_CinemaArcDeckEntry> entries = _collectEntries();
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double maxW =
              constraints.hasBoundedWidth ? constraints.maxWidth : 372.0;
          final double deckWidth = maxW.clamp(308.0, 440.0);
          const double deckHeight = 68.0;
          const double arcRadius = 480.0;
          const double apexY = 18.0;
          const double topApexAngle = -math.pi * 0.5;
          final Offset arcCenter = Offset(deckWidth * 0.5, apexY + arcRadius);

          final double halfChord =
              math.min(arcRadius * 0.65, math.max(96.0, deckWidth * 0.5 - 22.0));
          final double halfSweep = math.asin(halfChord / arcRadius);

          double totalIntervals = 0.0;
          for (int i = 0; i < entries.length - 1; i++) {
            totalIntervals +=
                (entries[i].weight + entries[i + 1].weight) * 0.5 +
                (entries[i + 1].separatorBefore ? 0.14 : 0.0);
          }

          final List<double> itemAngles = <double>[];
          final List<double> separatorAngles = <double>[];
          if (entries.length == 1 || totalIntervals <= 0) {
            itemAngles.add(topApexAngle);
          } else {
            double cursor = 0.0;
            for (int i = 0; i < entries.length; i++) {
              final double norm = (cursor / totalIntervals) * 2.0 - 1.0;
              final double angle = topApexAngle + norm * halfSweep;
              itemAngles.add(angle);
              if (i < entries.length - 1) {
                final double baseStep =
                    (entries[i].weight + entries[i + 1].weight) * 0.5;
                final double sepExtra =
                    entries[i + 1].separatorBefore ? 0.14 : 0.0;
                if (entries[i + 1].separatorBefore) {
                  final double midNorm =
                      ((cursor + (baseStep + sepExtra) * 0.5) /
                              totalIntervals) *
                          2.0 -
                      1.0;
                  separatorAngles.add(topApexAngle + midNorm * halfSweep);
                }
                cursor += baseStep + sepExtra;
              }
            }
          }

          return Center(
            child: SizedBox(
              width: deckWidth,
              height: deckHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _CinemaQuickDeckArcPainter(
                          arcCenter: arcCenter,
                          arcRadius: arcRadius,
                          startAngle: topApexAngle - halfSweep - 0.045,
                          sweepAngle: (halfSweep + 0.045) * 2.0,
                          separatorAngles: separatorAngles,
                        ),
                      ),
                    ),
                  ),
                  for (int i = 0; i < entries.length; i++)
                    _CinemaArcPositionedNode(
                      entry: entries[i],
                      centerX:
                          arcCenter.dx + arcRadius * math.cos(itemAngles[i]),
                      centerY:
                          arcCenter.dy + arcRadius * math.sin(itemAngles[i]),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

@immutable
class _CinemaArcDeckEntry {
  final String label;
  final bool isActive;
  final Color accentColor;
  final bool filledWhenActive;
  final IconData? icon;
  final double weight;
  final bool separatorBefore;
  final VoidCallback? onTap;

  const _CinemaArcDeckEntry({
    required this.label,
    required this.isActive,
    required this.accentColor,
    required this.filledWhenActive,
    required this.weight,
    this.icon,
    this.separatorBefore = false,
    this.onTap,
  });
}

class _CinemaArcPositionedNode extends StatelessWidget {
  final _CinemaArcDeckEntry entry;
  final double centerX;
  final double centerY;

  const _CinemaArcPositionedNode({
    required this.entry,
    required this.centerX,
    required this.centerY,
  });

  @override
  Widget build(BuildContext context) {
    const double boxW = 80.0;
    const double boxH = 32.0;
    return Positioned(
      left: centerX - boxW * 0.5,
      top: centerY - boxH * 0.5,
      width: boxW,
      height: boxH,
      child: Center(
        child: _CinemaArcNodePill(entry: entry),
      ),
    );
  }
}

class _CinemaArcNodePill extends StatelessWidget {
  final _CinemaArcDeckEntry entry;

  const _CinemaArcNodePill({required this.entry});

  @override
  Widget build(BuildContext context) {
    final bool solidFill = entry.isActive && entry.filledWhenActive;
    final Color bgColor = solidFill
        ? entry.accentColor
        : (entry.isActive
            ? entry.accentColor.withValues(alpha: 0.18)
            : kCardDark.withValues(alpha: 0.88));
    final Color borderColor = entry.isActive
        ? entry.accentColor
        : Colors.white.withValues(alpha: 0.20);
    final Color fgColor = solidFill
        ? kObsidianBg
        : (entry.isActive ? entry.accentColor : Colors.white70);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: entry.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: EdgeInsets.symmetric(
          horizontal: entry.icon != null ? 5.5 : 6.5,
          vertical: 3.5,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14.0),
          border: Border.all(
            color: borderColor,
            width: entry.isActive ? 1.1 : 0.85,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (entry.icon != null) ...<Widget>[
              Icon(entry.icon, size: 9.5, color: fgColor),
              const SizedBox(width: 2.0),
            ],
            Text(
              entry.label,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                color: fgColor,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                height: 1.05,
                fontFeatures: const <FontFeature>[
                  FontFeature.tabularFigures(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CinemaQuickDeckArcPainter extends CustomPainter {
  final Offset arcCenter;
  final double arcRadius;
  final double startAngle;
  final double sweepAngle;
  final List<double> separatorAngles;

  const _CinemaQuickDeckArcPainter({
    required this.arcCenter,
    required this.arcRadius,
    required this.startAngle,
    required this.sweepAngle,
    required this.separatorAngles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Rect midRect = Rect.fromCircle(center: arcCenter, radius: arcRadius);
    final Rect outerRect =
        Rect.fromCircle(center: arcCenter, radius: arcRadius + 14.0);
    final Rect innerRect =
        Rect.fromCircle(center: arcCenter, radius: arcRadius - 14.0);

    // Smoked concentric radial band
    canvas.drawArc(
      midRect,
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = kSurfaceDark.withValues(alpha: 0.76)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 28.0
        ..strokeCap = StrokeCap.round,
    );

    // Subtle center radial guide line connecting all cinema pills
    canvas.drawArc(
      midRect,
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Outer & inner concentric rim hairlines
    final Paint rimPaint = Paint()
      ..color = kBorderDark.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    canvas.drawArc(outerRect, startAngle, sweepAngle, false, rimPaint);
    canvas.drawArc(innerRect, startAngle, sweepAngle, false, rimPaint);

    // Radial group separator ticks (Lens | Rack | EIS+AEL)
    final Paint tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.24)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    for (final double angle in separatorAngles) {
      final Offset p1 = Offset(
        arcCenter.dx + (arcRadius - 8.5) * math.cos(angle),
        arcCenter.dy + (arcRadius - 8.5) * math.sin(angle),
      );
      final Offset p2 = Offset(
        arcCenter.dx + (arcRadius + 8.5) * math.cos(angle),
        arcCenter.dy + (arcRadius + 8.5) * math.sin(angle),
      );
      canvas.drawLine(p1, p2, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CinemaQuickDeckArcPainter oldDelegate) {
    return oldDelegate.arcCenter != arcCenter ||
        oldDelegate.arcRadius != arcRadius ||
        oldDelegate.startAngle != startAngle ||
        oldDelegate.sweepAngle != sweepAngle ||
        oldDelegate.separatorAngles.length != separatorAngles.length;
  }
}

/// ARRI / Sony FX3 style crimson cinema Tally border around the viewfinder
/// when recording is active. Passes all pointer events through cleanly.
class VideoRecTallyBorder extends StatelessWidget {
  final bool isRecording;
  final Widget? child;
  final double borderRadius;
  final double strokeWidth;

  const VideoRecTallyBorder({
    super.key,
    required this.isRecording,
    this.child,
    this.borderRadius = 0.0,
    this.strokeWidth = 2.5,
  });

  @override
  Widget build(BuildContext context) {
    final Widget tallyOverlay = isRecording
        ? IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _CinemaTallyPainter(
                  borderRadius: borderRadius,
                  strokeWidth: strokeWidth,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          )
        : const SizedBox.shrink();

    if (child == null) {
      return tallyOverlay;
    }

    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        child!,
        if (isRecording) Positioned.fill(child: tallyOverlay),
      ],
    );
  }
}

class _CinemaTallyPainter extends CustomPainter {
  final double borderRadius;
  final double strokeWidth;

  const _CinemaTallyPainter({
    required this.borderRadius,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    const Color tallyRed = Color(0xFFFF2D20);
    final Rect insetRect = Offset.zero & size;
    final RRect outerRRect = RRect.fromRectAndRadius(
      insetRect.deflate(strokeWidth * 0.5),
      Radius.circular(borderRadius),
    );

    // Subtle inner crimson glow
    canvas.drawRRect(
      outerRRect.deflate(1.5),
      Paint()
        ..color = tallyRed.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 2.2,
    );

    // Crisp ARRI/FX3 tally frame
    canvas.drawRRect(
      outerRRect,
      Paint()
        ..color = tallyRed
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
  }

  @override
  bool shouldRepaint(covariant _CinemaTallyPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
