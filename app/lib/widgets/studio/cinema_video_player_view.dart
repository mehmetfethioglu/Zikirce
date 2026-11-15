import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:zamera_capture/zamera_capture.dart';

import '../../constants/camera_colors.dart';
import '../../models/media_archive_item.dart';
import '../../services/zamera_media_archive_store.dart';
import 'sticker_studio_sheet.dart';

/// Embedded Cinema Video Player with SMPTE timecode, speed/mute controls,
/// Pro Video telemetry card, and 1-tap Frame-to-Photo / Frame-to-Sticker extraction.
class CinemaVideoPlayerView extends StatefulWidget {
  final ZameraMediaItem item;
  final MediaArchiveRepository? archiveRepository;
  final ValueChanged<ZameraMediaItem>? onFrameExtractedToArchive;
  final ValueChanged<ZameraMediaItem>? onStickerArchived;

  const CinemaVideoPlayerView({
    super.key,
    required this.item,
    this.archiveRepository,
    this.onFrameExtractedToArchive,
    this.onStickerArchived,
  });

  /// Formats [ms] as SMPTE timecode `HH:MM:SS:FF` at [fps].
  static String formatSmpte(int ms, int fps) {
    final safeFps = fps <= 0 ? 30 : fps;
    final clampedMs = ms < 0 ? 0 : ms;
    final totalSec = clampedMs ~/ 1000;
    final remMs = clampedMs % 1000;
    final ff = ((remMs * safeFps) ~/ 1000).clamp(0, safeFps - 1);
    final hh = (totalSec ~/ 3600).toString().padLeft(2, '0');
    final mm = ((totalSec % 3600) ~/ 60).toString().padLeft(2, '0');
    final ss = (totalSec % 60).toString().padLeft(2, '0');
    final ffStr = ff.toString().padLeft(2, '0');
    return '$hh:$mm:$ss:$ffStr';
  }

  @override
  State<CinemaVideoPlayerView> createState() => _CinemaVideoPlayerViewState();
}

class _CinemaVideoPlayerViewState extends State<CinemaVideoPlayerView> {
  static const List<double> _speedOptions = <double>[0.5, 1.0, 2.0];

  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasPlaybackError = false;
  bool _isMuted = false;
  double _playbackSpeed = 1.0;
  int _positionMs = 0;
  int _durationMs = 0;
  bool _isExtractingFrame = false;
  bool _isScrubbing = false;

  @override
  void initState() {
    super.initState();
    _durationMs = widget.item.durationMs ?? 0;
    _initController();
  }

  @override
  void didUpdateWidget(covariant CinemaVideoPlayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.primaryPath != widget.item.primaryPath) {
      _disposeController();
      _isInitialized = false;
      _hasPlaybackError = false;
      _positionMs = 0;
      _durationMs = widget.item.durationMs ?? 0;
      _initController();
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _disposeController() {
    final ctrl = _controller;
    _controller = null;
    if (ctrl != null) {
      ctrl.removeListener(_onControllerTick);
      try {
        ctrl.dispose();
      } catch (e) {
        debugPrint('CinemaVideoPlayerView dispose warning: $e');
      }
    }
  }

  Future<void> _initController() async {
    final path = widget.item.primaryPath;
    if (path.isEmpty || !File(path).existsSync()) {
      if (mounted) {
        setState(() {
          _hasPlaybackError = true;
          _isInitialized = false;
        });
      }
      return;
    }

    final ctrl = VideoPlayerController.file(File(path));
    _controller = ctrl;
    ctrl.addListener(_onControllerTick);
    try {
      await ctrl.initialize();
      await ctrl.setLooping(true);
      if (!mounted || _controller != ctrl) return;
      setState(() {
        _isInitialized = true;
        _hasPlaybackError = false;
        _durationMs = ctrl.value.duration.inMilliseconds > 0
            ? ctrl.value.duration.inMilliseconds
            : (widget.item.durationMs ?? 0);
      });
    } catch (e) {
      debugPrint('CinemaVideoPlayerView init fallback: $e');
      if (!mounted || _controller != ctrl) return;
      setState(() {
        _isInitialized = false;
        _hasPlaybackError = true;
      });
    }
  }

  void _onControllerTick() {
    final ctrl = _controller;
    if (ctrl == null || !mounted || _isScrubbing) return;
    final val = ctrl.value;
    final pos = val.position.inMilliseconds;
    final dur = val.duration.inMilliseconds;
    if (pos != _positionMs || (dur > 0 && dur != _durationMs)) {
      setState(() {
        _positionMs = pos;
        if (dur > 0) _durationMs = dur;
      });
    }
  }

  Future<void> _togglePlayPause() async {
    final ctrl = _controller;
    if (ctrl == null || !_isInitialized) return;
    try {
      if (ctrl.value.isPlaying) {
        await ctrl.pause();
      } else {
        await ctrl.play();
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('CinemaVideoPlayerView play/pause error: $e');
    }
  }

  Future<void> _cycleSpeed() async {
    final nextIdx =
        (_speedOptions.indexOf(_playbackSpeed) + 1) % _speedOptions.length;
    final next = _speedOptions[nextIdx];
    setState(() => _playbackSpeed = next);
    final ctrl = _controller;
    if (ctrl != null && _isInitialized) {
      try {
        await ctrl.setPlaybackSpeed(next);
      } catch (e) {
        debugPrint('CinemaVideoPlayerView speed error: $e');
      }
    }
  }

  Future<void> _toggleMute() async {
    final next = !_isMuted;
    setState(() => _isMuted = next);
    final ctrl = _controller;
    if (ctrl != null && _isInitialized) {
      try {
        await ctrl.setVolume(next ? 0.0 : 1.0);
      } catch (e) {
        debugPrint('CinemaVideoPlayerView mute error: $e');
      }
    }
  }

  Future<void> _captureFrame({required bool openStickerStudio}) async {
    if (_isExtractingFrame) return;
    setState(() => _isExtractingFrame = true);
    HapticFeedback.mediumImpact();
    try {
      if (_controller != null &&
          _isInitialized &&
          _controller!.value.isPlaying) {
        await _controller!.pause();
      }
      final out = await ZameraCapture.extractVideoFrameJpeg(
        videoPath: widget.item.primaryPath,
        positionMs: _positionMs,
      );
      if (!mounted) return;
      final jpegPath = out['jpegPath']?.toString();
      if (jpegPath == null || jpegPath.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video karesi çıkarılamadı.')),
        );
        return;
      }

      if (openStickerStudio) {
        await StickerStudioSheet.show(
          context,
          sourceImagePath: jpegPath,
          focusNorm: const Offset(0.5, 0.45),
          isFrontCamera: widget.item.isFrontCamera,
          sourceMediaId: widget.item.id,
          archiveRepository: widget.archiveRepository,
          onStickerArchived: widget.onStickerArchived,
        );
      } else {
        final frameItem = ZameraMediaItem(
          id: 'frm_${DateTime.now().microsecondsSinceEpoch}',
          kind: ZameraMediaKind.photo,
          createdAt: DateTime.now(),
          primaryPath: jpegPath,
          cameraId: widget.item.cameraId,
          width: (out['width'] as num?)?.toInt() ?? widget.item.width,
          height: (out['height'] as num?)?.toInt() ?? widget.item.height,
          colorSpaceTag: widget.item.colorStandard ?? 'BT.709',
          sourceMediaId: widget.item.id,
        );
        await widget.archiveRepository?.addOrUpdate(frameItem);
        widget.onFrameExtractedToArchive?.call(frameItem);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video karesi fotoğraf arşivine kaydedildi!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kare yakalama hatası: $e')),
      );
    } finally {
      if (mounted) setState(() => _isExtractingFrame = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fps = widget.item.fps ?? 30;
    final effectiveDurationMs = _durationMs > 0 ? _durationMs : 1;
    final resLabel = (widget.item.height ?? 0) >= 2160 ? '4K UHD' : '1080p FHD';
    final sizeMb = widget.item.fileSizeBytes != null
        ? '${(widget.item.fileSizeBytes! / (1024 * 1024)).toStringAsFixed(1)} MB'
        : '—';
    final isPlaying = _controller?.value.isPlaying == true;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cinema Viewport
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              height: 290,
              color: Colors.black,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_isInitialized && _controller != null)
                    AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio > 0
                          ? _controller!.value.aspectRatio
                          : (16 / 9),
                      child: VideoPlayer(_controller!),
                    )
                  else
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _hasPlaybackError
                              ? Icons.movie_creation_outlined
                              : Icons.play_circle_outline_rounded,
                          color: kIosYellow,
                          size: 48,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$resLabel · ${fps}FPS · ${widget.item.codec ?? 'HEVC'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _hasPlaybackError
                              ? 'Önizleme oynatıcısı bu cihazda başlatılamadı; telemetri & kare çıkarma aktif.'
                              : 'Sinema oynatıcısı hazırlanıyor...',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: kIosYellow.withValues(alpha: 0.65),
                        ),
                      ),
                      child: Text(
                        CinemaVideoPlayerView.formatSmpte(_positionMs, fps),
                        key: const ValueKey('video_smpte_timecode'),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w800,
                          color: kIosYellow,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Scrubber + Playback Controls
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF121620),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: kIosYellow,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: kIosYellow,
                  ),
                  child: Slider(
                    key: const ValueKey('video_timeline_slider'),
                    value: _positionMs.clamp(0, effectiveDurationMs).toDouble(),
                    min: 0.0,
                    max: effectiveDurationMs.toDouble(),
                    onChangeStart: (_) => setState(() => _isScrubbing = true),
                    onChanged: (v) => setState(() => _positionMs = v.round()),
                    onChangeEnd: (v) async {
                      setState(() => _isScrubbing = false);
                      final ctrl = _controller;
                      if (ctrl != null && _isInitialized) {
                        try {
                          await ctrl.seekTo(Duration(milliseconds: v.round()));
                        } catch (e) {
                          debugPrint('Video seek warning: $e');
                        }
                      }
                    },
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      key: const ValueKey('video_play_pause_btn'),
                      onPressed: _isInitialized ? _togglePlayPause : null,
                      icon: Icon(
                        isPlaying
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_filled_rounded,
                        color: kIosYellow,
                        size: 32,
                      ),
                    ),
                    Text(
                      '${CinemaVideoPlayerView.formatSmpte(_positionMs, fps)} / ${CinemaVideoPlayerView.formatSmpte(_durationMs, fps)}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontFamily: 'monospace',
                        color: Colors.white70,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      key: const ValueKey('video_speed_btn'),
                      onPressed: _cycleSpeed,
                      child: Text(
                        '${_playbackSpeed}x',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: kZameraCyan,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('video_mute_btn'),
                      onPressed: _toggleMute,
                      icon: Icon(
                        _isMuted
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        color: _isMuted ? Colors.white38 : Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Frame Capture & Frame-to-Sticker Actions
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('video_capture_frame_btn'),
                  style: FilledButton.styleFrom(
                    backgroundColor: kZameraCyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  onPressed: _isExtractingFrame
                      ? null
                      : () => _captureFrame(openStickerStudio: false),
                  icon: const Icon(Icons.photo_camera_outlined, size: 17),
                  label: const Text(
                    'Kare Yakala',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('video_frame_sticker_btn'),
                  style: FilledButton.styleFrom(
                    backgroundColor: kIosYellow,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  onPressed: _isExtractingFrame
                      ? null
                      : () => _captureFrame(openStickerStudio: true),
                  icon: const Icon(Icons.content_cut_rounded, size: 17),
                  label: const Text(
                    'Kareden Sticker Kes',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Pro Video Telemetry Card
          Container(
            key: const ValueKey('video_telemetry_card'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF121620),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PRO VİDEO SİNEMA TELEMETRİSİ',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _TelemetryPill(label: 'Çözünürlük', value: resLabel),
                    _TelemetryPill(label: 'Kare Hızı', value: '$fps FPS'),
                    _TelemetryPill(
                      label: 'Codec',
                      value: widget.item.codec ?? 'HEVC',
                    ),
                    _TelemetryPill(
                      label: 'Bitrate',
                      value: widget.item.bitrateMbps != null
                          ? '${widget.item.bitrateMbps!.toStringAsFixed(0)} Mbps'
                          : '—',
                    ),
                    _TelemetryPill(
                      label: 'Profil',
                      value: widget.item.videoProfile ?? 'REC.709',
                    ),
                    _TelemetryPill(
                      label: 'Renk Transferi',
                      value:
                          '${widget.item.colorStandard ?? 'BT.709'} · ${widget.item.colorTransfer ?? 'SDR'}',
                    ),
                    _TelemetryPill(
                      label: 'Düşen Kare',
                      value: '${widget.item.droppedFrames ?? 0}',
                    ),
                    _TelemetryPill(label: 'Dosya Boyutu', value: sizeMb),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TelemetryPill extends StatelessWidget {
  final String label;
  final String value;

  const _TelemetryPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 9, color: Colors.white54),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11.5,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
