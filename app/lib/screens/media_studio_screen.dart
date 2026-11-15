import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zamera_capture/zamera_capture.dart';

import '../constants/camera_colors.dart';
import '../models/inspector_colorimetry.dart';
import '../models/media_archive_item.dart';
import '../painters/checkerboard_and_lift_painter.dart';
import '../services/zamera_media_archive_store.dart';
import '../widgets/studio/cinema_video_player_view.dart';
import '../widgets/studio/media_archive_grid_view.dart';
import '../widgets/studio/portrait_refocus_panel.dart';
import '../widgets/studio/pro_exif_histogram_sheet.dart';
import '../widgets/studio/split_ab_comparison_viewer.dart';
import '../widgets/studio/sticker_studio_sheet.dart';

enum _StudioTool {
  none,
  info,
  colorSplit,
  portrait,
}

class _DecodedImageCacheEntry {
  final Uint8List rgbaBytes;
  final int width;
  final int height;
  final RgbHistogramData histogram;

  const _DecodedImageCacheEntry({
    required this.rgbaBytes,
    required this.width,
    required this.height,
    required this.histogram,
  });
}

/// Full-Screen Leica / iOS Style Pro Media Studio for inspecting photos, videos,
/// RAW DNGs, and transparent PNG stickers with persistent archive filmstrip & grid.
class MediaStudioScreen extends StatefulWidget {
  final MediaArchiveRepository archiveRepository;
  final String? initialMediaId;
  final double initialPortraitAperture;
  final int initialPortraitLightingIndex;
  final double initialPortraitLightIntensity;
  final double initialPortraitSubjectRadius;
  final Offset? initialFocusTapNorm;

  const MediaStudioScreen({
    super.key,
    required this.archiveRepository,
    this.initialMediaId,
    this.initialPortraitAperture = 2.8,
    this.initialPortraitLightingIndex = 0,
    this.initialPortraitLightIntensity = 0.80,
    this.initialPortraitSubjectRadius = 0.36,
    this.initialFocusTapNorm,
  });

  static Future<void> open(
    BuildContext context, {
    required MediaArchiveRepository archiveRepository,
    String? initialMediaId,
    double initialPortraitAperture = 2.8,
    int initialPortraitLightingIndex = 0,
    double initialPortraitLightIntensity = 0.80,
    double initialPortraitSubjectRadius = 0.36,
    Offset? initialFocusTapNorm,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MediaStudioScreen(
          archiveRepository: archiveRepository,
          initialMediaId: initialMediaId,
          initialPortraitAperture: initialPortraitAperture,
          initialPortraitLightingIndex: initialPortraitLightingIndex,
          initialPortraitLightIntensity: initialPortraitLightIntensity,
          initialPortraitSubjectRadius: initialPortraitSubjectRadius,
          initialFocusTapNorm: initialFocusTapNorm,
        ),
      ),
    );
  }

  @override
  State<MediaStudioScreen> createState() => _MediaStudioScreenState();
}

class _MediaStudioScreenState extends State<MediaStudioScreen> {
  static const int _maxDecodedCacheEntries = 4;

  late final PageController _pageController;
  final ScrollController _filmstripScrollController = ScrollController();
  final ScrollController _dockScrollController = ScrollController();
  final LinkedHashMap<String, _DecodedImageCacheEntry> _decodedCache =
      LinkedHashMap<String, _DecodedImageCacheEntry>();

  int _currentIndex = 0;
  bool _showGridView = false;
  ZameraArchiveFilter _gridFilter = ZameraArchiveFilter.all;
  _StudioTool _activeTool = _StudioTool.none;
  bool _interactionLocked = false;

  // Per-active-photo inspection/editing state
  bool _abSplitEnabled = false;
  bool _showingOemFallback = false;
  bool _portraitEnabled = false;
  double _editAperture = 2.8;
  int _editLighting = 0;
  double _editIntensity = 0.80;
  Offset _focusNorm = const Offset(0.5, 0.45);
  bool _isReprocessing = false;
  int _decodeGeneration = 0;
  InspectedPixelMeasurement? _pixelMeasurement;
  String? _statusHint;

  List<ZameraMediaItem> get _items => widget.archiveRepository.items;

  ZameraMediaItem? get _currentItem {
    final list = _items;
    if (list.isEmpty) return null;
    final idx = _currentIndex.clamp(0, list.length - 1);
    return list[idx];
  }

  @override
  void initState() {
    super.initState();
    widget.archiveRepository.addListener(_onArchiveChanged);

    var startIdx = 0;
    if (widget.initialMediaId != null) {
      final found = _items.indexWhere((e) => e.id == widget.initialMediaId);
      if (found >= 0) startIdx = found;
    }
    _currentIndex = startIdx;
    _pageController = PageController(initialPage: startIdx);
    _syncStateForCurrentItem(autoOpenPortraitDock: false);
  }

  @override
  void dispose() {
    _decodeGeneration++;
    widget.archiveRepository.removeListener(_onArchiveChanged);
    _pageController.dispose();
    _filmstripScrollController.dispose();
    _dockScrollController.dispose();
    _decodedCache.clear();
    super.dispose();
  }

  void _onArchiveChanged() {
    if (!mounted) return;
    final len = _items.length;
    setState(() {
      if (len == 0) {
        _currentIndex = 0;
      } else if (_currentIndex >= len) {
        _currentIndex = len - 1;
      }
    });
  }

  void _syncStateForCurrentItem({bool autoOpenPortraitDock = false}) {
    final item = _currentItem;
    if (item == null) return;

    _interactionLocked = false;
    _showingOemFallback = false;
    _abSplitEnabled = item.hasOemComparison && !item.isPortrait;
    _portraitEnabled = item.isPortrait;
    _editAperture = item.portraitAperture ?? widget.initialPortraitAperture;
    _editLighting =
        item.portraitLightingIndex ?? widget.initialPortraitLightingIndex;
    _editIntensity =
        item.portraitLightIntensity ?? widget.initialPortraitLightIntensity;
    _focusNorm =
        (item.portraitFocusX != null && item.portraitFocusY != null)
        ? Offset(item.portraitFocusX!, item.portraitFocusY!)
        : (widget.initialFocusTapNorm ??
              (item.isPortrait
                  ? const Offset(0.5, 0.45)
                  : const Offset(0.5, 0.5)));

    if (autoOpenPortraitDock && item.isPortrait) {
      _activeTool = _StudioTool.portrait;
    } else if (item.kind == ZameraMediaKind.video) {
      _activeTool = _StudioTool.none;
    } else if (item.kind == ZameraMediaKind.sticker &&
        _activeTool == _StudioTool.portrait) {
      _activeTool = _StudioTool.info;
    }

    if (item.kind == ZameraMediaKind.photo ||
        item.kind == ZameraMediaKind.sticker) {
      _pixelMeasurement = _buildFallbackMeasurement(item, _focusNorm);
      final cached = _decodedCache[item.primaryPath];
      if (cached != null) {
        _pixelMeasurement = _sampleFromEntry(item, cached, _focusNorm);
      } else {
        _decodeImageAsync(item.primaryPath, item);
      }
    } else {
      _pixelMeasurement = null;
    }

    _statusHint = switch (item.kind) {
      ZameraMediaKind.photo =>
        'Uzun bas: Sticker kes · Çift dokun: Yakınlaştır',
      ZameraMediaKind.video => 'Sinema Oynatıcı · Kare veya Sticker yakalayın',
      ZameraMediaKind.sticker =>
        'Şeffaf PNG Sticker · Kopyala veya Paylaş',
    };
  }

  InspectedPixelMeasurement _buildFallbackMeasurement(
    ZameraMediaItem item,
    Offset normPoint,
  ) {
    final w = item.width ?? 1;
    final h = item.height ?? 1;
    return InspectedPixelMeasurement.fromSrgb8(
      normalizedPoint: normPoint,
      pixelX: (normPoint.dx * (w - 1)).round().clamp(0, math.max(0, w - 1)),
      pixelY: (normPoint.dy * (h - 1)).round().clamp(0, math.max(0, h - 1)),
      r: 128,
      g: 128,
      b: 128,
      colorSpaceTag: item.colorSpaceTag ?? 'sRGB',
      isDecodedPixel: false,
      overrideLabD50: item.centerLabD50,
    );
  }

  InspectedPixelMeasurement _sampleFromEntry(
    ZameraMediaItem item,
    _DecodedImageCacheEntry entry,
    Offset normPoint,
  ) {
    final w = entry.width;
    final h = entry.height;
    final px = (normPoint.dx.clamp(0.0, 1.0) * (w - 1)).round().clamp(0, w - 1);
    final py = (normPoint.dy.clamp(0.0, 1.0) * (h - 1)).round().clamp(0, h - 1);
    final idx = (py * w + px) * 4;
    if (idx + 3 >= entry.rgbaBytes.length) {
      return _buildFallbackMeasurement(item, normPoint);
    }
    final a = entry.rgbaBytes[idx + 3];
    var r = entry.rgbaBytes[idx];
    var g = entry.rgbaBytes[idx + 1];
    var b = entry.rgbaBytes[idx + 2];
    if (a > 0 && a < 255) {
      r = ((r * 255) / a).round().clamp(0, 255);
      g = ((g * 255) / a).round().clamp(0, 255);
      b = ((b * 255) / a).round().clamp(0, 255);
    }
    return InspectedPixelMeasurement.fromSrgb8(
      normalizedPoint: normPoint,
      pixelX: px,
      pixelY: py,
      r: r,
      g: g,
      b: b,
      colorSpaceTag: _showingOemFallback
          ? 'sRGB (OEM)'
          : (item.colorSpaceTag ?? 'sRGB'),
      isDecodedPixel: true,
    );
  }

  Future<void> _decodeImageAsync(String path, ZameraMediaItem item) async {
    if (path.isEmpty) return;
    final file = File(path);
    if (!file.existsSync()) return;
    final gen = ++_decodeGeneration;
    try {
      final bytes = await file.readAsBytes();
      if (!mounted || gen != _decodeGeneration) return;

      final codec = await ui.instantiateImageCodec(bytes);
      Uint8List? rgba;
      var imgW = 0;
      var imgH = 0;
      try {
        final frame = await codec.getNextFrame();
        final uiImage = frame.image;
        try {
          imgW = uiImage.width;
          imgH = uiImage.height;
          final byteData = await uiImage.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          if (byteData != null) {
            rgba = byteData.buffer.asUint8List(
              byteData.offsetInBytes,
              byteData.lengthInBytes,
            );
          }
        } finally {
          uiImage.dispose();
        }
      } finally {
        codec.dispose();
      }
      if (!mounted || gen != _decodeGeneration || rgba == null) return;

      final histogram = computeRgbaHistogram64(rgba, imgW, imgH);
      final entry = _DecodedImageCacheEntry(
        rgbaBytes: rgba,
        width: imgW,
        height: imgH,
        histogram: histogram,
      );
      if (_decodedCache.length >= _maxDecodedCacheEntries) {
        _decodedCache.remove(_decodedCache.keys.first);
      }
      _decodedCache[path] = entry;

      if (_currentItem?.id == item.id) {
        setState(() {
          _pixelMeasurement = _sampleFromEntry(item, entry, _focusNorm);
        });
      }
    } catch (e) {
      debugPrint('MediaStudioScreen._decodeImageAsync warning: $e');
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _syncStateForCurrentItem();
    });
    _scrollFilmstripToIndex(index);
  }

  void _scrollFilmstripToIndex(int index) {
    if (!_filmstripScrollController.hasClients) return;
    final targetOffset = math.max(0.0, index * 56.0 - 120.0);
    _filmstripScrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _jumpToMediaItem(ZameraMediaItem item) {
    final idx = _items.indexWhere((e) => e.id == item.id);
    if (idx < 0) return;
    setState(() {
      _showGridView = false;
      _currentIndex = idx;
      _syncStateForCurrentItem();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(idx);
      }
      _scrollFilmstripToIndex(idx);
    });
  }

  void _updateColorimeterSample(ZameraMediaItem item, Offset norm) {
    final entry = _decodedCache[item.primaryPath];
    setState(() {
      _focusNorm = norm;
      _pixelMeasurement = entry != null
          ? _sampleFromEntry(item, entry, norm)
          : _buildFallbackMeasurement(item, norm);
    });
  }

  Future<void> _triggerPortraitRefocus(
    ZameraMediaItem item, {
    bool saveToGallery = false,
  }) async {
    final sourcePath = item.oemPath ?? item.primaryPath;
    if (sourcePath.isEmpty || _isReprocessing) return;
    setState(() {
      _isReprocessing = true;
      _statusHint = saveToGallery
          ? 'Portre düzenlemesi kaydediliyor...'
          : 'Portre odağı ƒ ${_editAperture.toStringAsFixed(1)} hesaplanıyor...';
    });

    try {
      final out = await ZameraCapture.reprocessPortraitPhoto(
        sourceJpegPath: sourcePath,
        aperture: _editAperture,
        lightingMode: _portraitEnabled ? _editLighting : 0,
        lightIntensity: _editIntensity,
        subjectRadiusRatio:
            item.portraitSubjectRadiusRatio ??
            widget.initialPortraitSubjectRadius,
        focusX: _focusNorm.dx,
        focusY: _focusNorm.dy,
        isFrontCamera: item.isFrontCamera,
        saveToGallery: saveToGallery,
        portraitEnabled: _portraitEnabled,
      );
      if (!mounted) return;
      final newPath =
          out['reprocessedJpegPath']?.toString() ?? out['jpegPath']?.toString();
      final updated = item.copyWith(
        primaryPath: (newPath != null && newPath.isNotEmpty)
            ? newPath
            : item.primaryPath,
        isPortrait: _portraitEnabled,
        portraitAperture: _editAperture,
        portraitLightingIndex: _editLighting,
        portraitLightIntensity: _editIntensity,
        portraitFocusX: _focusNorm.dx,
        portraitFocusY: _focusNorm.dy,
      );
      await widget.archiveRepository.addOrUpdate(updated);
      if (!mounted) return;
      setState(() {
        _statusHint = saveToGallery
            ? 'Değişiklikler galeriye ve arşive kaydedildi!'
            : 'Portre odağı güncellendi';
      });
      if (newPath != null && newPath.isNotEmpty) {
        _decodeImageAsync(newPath, updated);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusHint = 'Yeniden odaklama hatası: $e';
      });
    } finally {
      if (mounted) setState(() => _isReprocessing = false);
    }
  }

  Future<void> _openStickerStudio(
    ZameraMediaItem item,
    Offset focusNorm,
  ) async {
    final sourcePath =
        (item.isPortrait && item.oemPath != null && item.oemPath!.isNotEmpty)
        ? item.oemPath!
        : item.primaryPath;
    if (sourcePath.isEmpty) return;

    await StickerStudioSheet.show(
      context,
      sourceImagePath: sourcePath,
      focusNorm: focusNorm,
      subjectRadiusRatio:
          item.portraitSubjectRadiusRatio ?? widget.initialPortraitSubjectRadius,
      isFrontCamera: item.isFrontCamera,
      sourceMediaId: item.id,
      archiveRepository: widget.archiveRepository,
      onStickerArchived: (stickerItem) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sticker arşive eklendi!'),
            duration: Duration(seconds: 2),
          ),
        );
      },
    );
  }

  Future<void> _sharePaths(
    List<String> paths, {
    String? mimeType,
    String? title,
  }) async {
    final existing = paths.where((p) => p.isNotEmpty).toList(growable: false);
    if (existing.isEmpty) return;
    try {
      await ZameraCapture.shareMediaFiles(
        filePaths: existing,
        mimeType: mimeType,
        title: title,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Paylaşım hatası: $e')),
      );
    }
  }

  Future<void> _confirmDelete(ZameraMediaItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141821),
        title: const Text(
          'Medyayı Sil',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Bu öğe Zamera arşivinden ve cihaz depolamasından silinecek. Devam edilsin mi?',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            key: const ValueKey('studio_confirm_delete_btn'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF453A),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.archiveRepository.remove(item.id, deleteDiskFiles: true);
    if (!mounted) return;
    if (_items.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _currentIndex = _currentIndex.clamp(0, _items.length - 1);
      _syncStateForCurrentItem();
    });
  }

  Future<void> _quickCopySticker(ZameraMediaItem sticker) async {
    try {
      final ok = await ZameraCapture.copyPngToClipboard(
        pngPath: sticker.primaryPath,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Sticker panoya kopyalandı!'
                : 'Sticker panoya kopyalanamadı.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pano hatası: $e')),
      );
    }
  }

  void _toggleTool(_StudioTool tool) {
    HapticFeedback.selectionClick();
    setState(() {
      _activeTool = _activeTool == tool ? _StudioTool.none : tool;
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final current = _currentItem;
    final kindLabel = switch (current?.kind) {
      ZameraMediaKind.video => 'PRO VİDEO',
      ZameraMediaKind.sticker => 'STICKER',
      _ => current?.isPortrait == true ? 'PORTRE' : 'FOTOĞRAF',
    };

    return Scaffold(
      backgroundColor: const Color(0xFF07090D),
      body: SafeArea(
        child: Column(
          children: [
            // Top Studio Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
              child: Row(
                children: [
                  IconButton(
                    key: const ValueKey('studio_back_btn'),
                    tooltip: 'Kameraya Dön',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              _showGridView
                                  ? 'Zamera Arşivi (${items.length})'
                                  : '$kindLabel · ${items.isEmpty ? 0 : _currentIndex + 1}/${items.length}',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        if (_statusHint != null && !_showGridView)
                          Text(
                            _statusHint!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: kZameraCyan,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('studio_toggle_grid_btn'),
                    tooltip: _showGridView ? 'Stüdyoya Dön' : 'Tüm Medya Izgarası',
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() => _showGridView = !_showGridView);
                    },
                    icon: Icon(
                      _showGridView
                          ? Icons.photo_size_select_actual_outlined
                          : Icons.grid_view_rounded,
                      color: _showGridView ? kIosYellow : Colors.white,
                    ),
                  ),
                  if (current != null && !_showGridView) ...[
                    IconButton(
                      key: const ValueKey('studio_favorite_btn'),
                      tooltip: 'Favorile',
                      onPressed: () =>
                          widget.archiveRepository.toggleFavorite(current.id),
                      icon: Icon(
                        current.isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: current.isFavorite
                            ? const Color(0xFFFF453A)
                            : Colors.white70,
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('studio_top_share_btn'),
                      tooltip: 'Paylaş',
                      onPressed: () => _sharePaths(
                        [current.primaryPath],
                        mimeType: switch (current.kind) {
                          ZameraMediaKind.video => 'video/mp4',
                          ZameraMediaKind.sticker => 'image/png',
                          ZameraMediaKind.photo => 'image/jpeg',
                        },
                      ),
                      icon: const Icon(
                        Icons.ios_share_rounded,
                        color: kZameraCyan,
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('studio_delete_btn'),
                      tooltip: 'Sil',
                      onPressed: () => _confirmDelete(current),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Center Stage: Grid OR Swipeable Media PageView
            Expanded(
              child: _showGridView
                  ? MediaArchiveGridView(
                      allItems: items,
                      activeFilter: _gridFilter,
                      selectedItemId: current?.id,
                      onFilterSelected: (f) => setState(() => _gridFilter = f),
                      onSelectItem: _jumpToMediaItem,
                      onQuickCopySticker: _quickCopySticker,
                      onQuickShareSticker: (s) => _sharePaths(
                        [s.primaryPath],
                        mimeType: 'image/png',
                        title: 'Sticker Paylaş',
                      ),
                    )
                  : items.isEmpty
                  ? const Center(
                      child: Text(
                        'Henüz Zamera ile çekilmiş medya yok.',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    )
                  : PageView.builder(
                      key: const ValueKey('studio_media_pager'),
                      controller: _pageController,
                      physics: _interactionLocked
                          ? const NeverScrollableScrollPhysics()
                          : const PageScrollPhysics(),
                      itemCount: items.length,
                      onPageChanged: _onPageChanged,
                      itemBuilder: (context, idx) {
                        final item = items[idx];
                        if (item.kind == ZameraMediaKind.video) {
                          return CinemaVideoPlayerView(
                            item: item,
                            archiveRepository: widget.archiveRepository,
                            onFrameExtractedToArchive: _jumpToMediaItem,
                          );
                        }
                        final displayPath =
                            (_showingOemFallback &&
                                item.hasOemComparison &&
                                idx == _currentIndex)
                            ? item.oemPath!
                            : item.primaryPath;
                        final cached = _decodedCache[displayPath];
                        return SplitAbComparisonViewer(
                          primaryImagePath: displayPath,
                          secondaryImagePath: item.oemPath,
                          primaryLabel: item.isPortrait
                              ? 'PORTRE'
                              : 'TRUECOLOR 1:1',
                          secondaryLabel: item.isPortrait
                              ? 'ORİJİNAL'
                              : 'STOK (OEM)',
                          isSticker: item.kind == ZameraMediaKind.sticker,
                          abSplitEnabled:
                              idx == _currentIndex &&
                              _abSplitEnabled &&
                              item.hasOemComparison &&
                              !_showingOemFallback,
                          colorimeterEnabled:
                              idx == _currentIndex &&
                              _activeTool == _StudioTool.colorSplit,
                          portraitRefocusEnabled: idx == _currentIndex
                              ? _portraitEnabled
                              : item.isPortrait,
                          isPortraitMode:
                              item.isPortrait ||
                              (idx == _currentIndex &&
                                  _activeTool == _StudioTool.portrait),
                          portraitAperture: idx == _currentIndex
                              ? _editAperture
                              : (item.portraitAperture ?? 2.8),
                          imageWidth: cached?.width ?? item.width,
                          imageHeight: cached?.height ?? item.height,
                          focusNorm: idx == _currentIndex
                              ? _focusNorm
                              : const Offset(0.5, 0.45),
                          pixelMeasurement: idx == _currentIndex
                              ? _pixelMeasurement
                              : null,
                          onInteractionLockChanged: (locked) {
                            if (locked != _interactionLocked) {
                              setState(() => _interactionLocked = locked);
                            }
                          },
                          onTapImage: (mapped) {
                            if (item.kind != ZameraMediaKind.photo) return;
                            if (_activeTool == _StudioTool.colorSplit ||
                                (!item.isPortrait &&
                                    _activeTool != _StudioTool.portrait)) {
                              _updateColorimeterSample(item, mapped);
                            } else {
                              setState(() {
                                _focusNorm = mapped;
                                if (!_portraitEnabled) _portraitEnabled = true;
                              });
                              _triggerPortraitRefocus(item);
                            }
                          },
                          onColorimeterDrag: (mapped) =>
                              _updateColorimeterSample(item, mapped),
                          onSubjectLift: (mapped) =>
                              _openStickerStudio(item, mapped),
                        );
                      },
                    ),
            ),

            // Expandable Pro Tool Dock Panel
            if (!_showGridView &&
                current != null &&
                current.kind != ZameraMediaKind.video) ...[
              if (_activeTool != _StudioTool.none)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 265),
                  child: SingleChildScrollView(
                    controller: _dockScrollController,
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                    child: _buildActiveToolPanel(current),
                  ),
                ),

              // Pro Tool Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: const BoxDecoration(
                  color: Color(0xFF0D1017),
                  border: Border(top: BorderSide(color: Colors.white10)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StudioDockButton(
                      key: const ValueKey('studio_tool_info_btn'),
                      icon: Icons.info_outline_rounded,
                      label: 'Bilgi & Hist',
                      selected: _activeTool == _StudioTool.info,
                      onTap: () => _toggleTool(_StudioTool.info),
                    ),
                    if (current.kind == ZameraMediaKind.photo)
                      _StudioDockButton(
                        key: const ValueKey('studio_tool_color_ab_btn'),
                        icon: Icons.compare_rounded,
                        label: 'A/B & Renk',
                        selected: _activeTool == _StudioTool.colorSplit,
                        onTap: () => _toggleTool(_StudioTool.colorSplit),
                      ),
                    if (current.kind == ZameraMediaKind.photo)
                      _StudioDockButton(
                        key: const ValueKey('studio_tool_portrait_btn'),
                        icon: Icons.blur_on_rounded,
                        label: 'Portre',
                        selected: _activeTool == _StudioTool.portrait,
                        onTap: () => _toggleTool(_StudioTool.portrait),
                      ),
                    if (current.kind == ZameraMediaKind.photo)
                      _StudioDockButton(
                        key: const ValueKey('studio_tool_sticker_btn'),
                        icon: Icons.content_cut_rounded,
                        label: 'Sticker Kes',
                        selected: false,
                        accentColor: kIosYellow,
                        onTap: () => _openStickerStudio(current, _focusNorm),
                      )
                    else if (current.kind == ZameraMediaKind.sticker)
                      _StudioDockButton(
                        key: const ValueKey('studio_sticker_copy_dock_btn'),
                        icon: Icons.content_copy_rounded,
                        label: 'Kopyala',
                        selected: false,
                        accentColor: kIosYellow,
                        onTap: () => _quickCopySticker(current),
                      ),
                  ],
                ),
              ),
            ],

            // Synced Bottom Filmstrip
            if (!_showGridView && items.isNotEmpty)
              Container(
                height: 60,
                color: const Color(0xFF090B10),
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: ListView.separated(
                  controller: _filmstripScrollController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (context, idx) {
                    final item = items[idx];
                    final selected = idx == _currentIndex;
                    return _FilmstripThumbnail(
                      item: item,
                      selected: selected,
                      onTap: () {
                        _pageController.animateToPage(
                          idx,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveToolPanel(ZameraMediaItem item) {
    final cached = _decodedCache[item.primaryPath];
    switch (_activeTool) {
      case _StudioTool.info:
        return ProExifHistogramCard(
          item: item,
          rgbHistogram: cached?.histogram,
          pixelMeasurement: _pixelMeasurement,
          showingOem: _showingOemFallback,
          onToggleOem: item.hasOemComparison
              ? () => setState(() => _showingOemFallback = !_showingOemFallback)
              : null,
          onShareJpeg: () => _sharePaths(
            [item.primaryPath],
            mimeType: item.kind == ZameraMediaKind.sticker
                ? 'image/png'
                : 'image/jpeg',
          ),
          onShareDng: item.hasRaw
              ? () => _sharePaths(
                  [item.dngPath!],
                  mimeType: 'image/x-adobe-dng',
                  title: 'RAW DNG Paylaş',
                )
              : null,
        );
      case _StudioTool.colorSplit:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (item.hasOemComparison)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SwitchListTile.adaptive(
                  key: const ValueKey('studio_ab_curtain_switch'),
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.white12),
                  ),
                  tileColor: const Color(0xFF121620),
                  activeThumbColor: kZameraCyan,
                  title: const Text(
                    'A/B Bölünmüş Karşılaştırma Perdesi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text(
                    'Perdeyi sürükleyip TrueColor / OEM farkını inceleyin',
                    style: TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                  value: _abSplitEnabled,
                  onChanged: (v) => setState(() => _abSplitEnabled = v),
                ),
              ),
            ProExifHistogramCard(
              item: item,
              rgbHistogram: cached?.histogram,
              pixelMeasurement: _pixelMeasurement,
              showingOem: _showingOemFallback,
              onToggleOem: item.hasOemComparison
                  ? () => setState(() => _abSplitEnabled = !_abSplitEnabled)
                  : null,
            ),
          ],
        );
      case _StudioTool.portrait:
        return PortraitRefocusPanel(
          portraitEnabled: _portraitEnabled,
          aperture: _editAperture,
          lightingIndex: _editLighting,
          lightIntensity: _editIntensity,
          isProcessing: _isReprocessing,
          onTogglePortrait: (next) {
            setState(() => _portraitEnabled = next);
            _triggerPortraitRefocus(item);
          },
          onApertureChanged: (v) => setState(() => _editAperture = v),
          onApertureCommit: (_) => _triggerPortraitRefocus(item),
          onIntensityChanged: (v) => setState(() => _editIntensity = v),
          onIntensityCommit: (_) => _triggerPortraitRefocus(item),
          onLightingSelected: (idx) {
            setState(() {
              _editLighting = idx;
              if (!_portraitEnabled && idx > 0) _portraitEnabled = true;
            });
            _triggerPortraitRefocus(item);
          },
          onSaveToGallery: () =>
              _triggerPortraitRefocus(item, saveToGallery: true),
        );
      case _StudioTool.none:
        return const SizedBox.shrink();
    }
  }
}

class _StudioDockButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color? accentColor;
  final VoidCallback onTap;

  const _StudioDockButton({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected
        ? Colors.black
        : (accentColor ?? Colors.white70);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? kIosYellow : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? kIosYellow
                : (accentColor?.withValues(alpha: 0.45) ?? Colors.white12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: fg),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilmstripThumbnail extends StatelessWidget {
  final ZameraMediaItem item;
  final bool selected;
  final VoidCallback onTap;

  const _FilmstripThumbnail({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final f = File(item.primaryPath);
    final hasFile = item.primaryPath.isNotEmpty && f.existsSync();
    return GestureDetector(
      key: ValueKey('filmstrip_thumb_${item.id}'),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: selected ? 52 : 46,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected ? kIosYellow : Colors.white24,
            width: selected ? 2.0 : 0.8,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (item.kind == ZameraMediaKind.sticker)
              const CustomPaint(
                painter: TransparencyCheckerboardPainter(tileSize: 6),
              ),
            if (item.kind == ZameraMediaKind.video)
              const ColoredBox(
                color: Color(0xFF141824),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: kIosYellow,
                  size: 22,
                ),
              )
            else if (hasFile)
              Image.file(
                f,
                fit: item.kind == ZameraMediaKind.sticker
                    ? BoxFit.contain
                    : BoxFit.cover,
              )
            else
              Icon(
                item.kind == ZameraMediaKind.sticker
                    ? Icons.content_cut_rounded
                    : Icons.photo_outlined,
                color: Colors.white38,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}
