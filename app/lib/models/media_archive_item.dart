import 'package:flutter/material.dart';
import 'package:zamera_capture/zamera_capture.dart';
import 'package:zamera_video/zamera_video.dart';

/// Media kinds stored in the persistent Zamera archive.
enum ZameraMediaKind {
  photo,
  video,
  sticker;

  static ZameraMediaKind fromName(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return ZameraMediaKind.photo;
  }
}

/// OCP-compliant archive filter definitions with Turkish UI labels & predicate matching.
enum ZameraArchiveFilter {
  all(labelTr: 'Tümü', icon: Icons.grid_view_rounded),
  photos(labelTr: 'Fotoğraf', icon: Icons.photo_outlined),
  videos(labelTr: 'Video', icon: Icons.videocam_outlined),
  portrait(labelTr: 'Portre', icon: Icons.blur_on_rounded),
  raw(labelTr: 'RAW', icon: Icons.raw_on_rounded),
  stickers(labelTr: "Sticker'larım", icon: Icons.content_cut_rounded);

  const ZameraArchiveFilter({required this.labelTr, required this.icon});

  final String labelTr;
  final IconData icon;

  bool matches(ZameraMediaItem item) {
    switch (this) {
      case ZameraArchiveFilter.all:
        return true;
      case ZameraArchiveFilter.photos:
        return item.kind == ZameraMediaKind.photo;
      case ZameraArchiveFilter.videos:
        return item.kind == ZameraMediaKind.video;
      case ZameraArchiveFilter.portrait:
        return item.kind == ZameraMediaKind.photo && item.isPortrait;
      case ZameraArchiveFilter.raw:
        return item.kind == ZameraMediaKind.photo && item.hasRaw;
      case ZameraArchiveFilter.stickers:
        return item.kind == ZameraMediaKind.sticker;
    }
  }
}

/// Immutable record representing any Zamera captured photo, video, extracted frame, or sticker.
class ZameraMediaItem {
  static int _idSequence = 0;

  final String id;
  final ZameraMediaKind kind;
  final DateTime createdAt;
  final String primaryPath;
  final String? oemPath;
  final String? dngPath;
  final String? mediaStoreUri;
  final String? mediaStoreDngUri;
  final String cameraId;
  final int? width;
  final int? height;
  final int? iso;
  final int? exposureTimeNs;
  final double? solvedCctKelvin;
  final String? colorSpaceTag;
  final bool rustIspActive;
  final bool isPortrait;
  final double? portraitAperture;
  final int? portraitLightingIndex;
  final double? portraitLightIntensity;
  final double? portraitFocusX;
  final double? portraitFocusY;
  final double? portraitSubjectRadiusRatio;
  final List<double>? rawHistogram32;
  final List<double>? centerLabD50;
  final int? durationMs;
  final int? fps;
  final double? bitrateMbps;
  final String? codec;
  final String? videoProfile;
  final String? colorStandard;
  final String? colorTransfer;
  final int? droppedFrames;
  final int? fileSizeBytes;
  final bool hasWhiteOutline;
  final String? sourceMediaId;
  final bool isFavorite;

  const ZameraMediaItem({
    required this.id,
    required this.kind,
    required this.createdAt,
    required this.primaryPath,
    this.oemPath,
    this.dngPath,
    this.mediaStoreUri,
    this.mediaStoreDngUri,
    this.cameraId = '2',
    this.width,
    this.height,
    this.iso,
    this.exposureTimeNs,
    this.solvedCctKelvin,
    this.colorSpaceTag,
    this.rustIspActive = false,
    this.isPortrait = false,
    this.portraitAperture,
    this.portraitLightingIndex,
    this.portraitLightIntensity,
    this.portraitFocusX,
    this.portraitFocusY,
    this.portraitSubjectRadiusRatio,
    this.rawHistogram32,
    this.centerLabD50,
    this.durationMs,
    this.fps,
    this.bitrateMbps,
    this.codec,
    this.videoProfile,
    this.colorStandard,
    this.colorTransfer,
    this.droppedFrames,
    this.fileSizeBytes,
    this.hasWhiteOutline = false,
    this.sourceMediaId,
    this.isFavorite = false,
  });

  bool get hasRaw => dngPath != null && dngPath!.isNotEmpty;
  bool get hasOemComparison => oemPath != null && oemPath!.isNotEmpty;
  bool get isFrontCamera =>
      cameraId == '1' || cameraId.toLowerCase().contains('front');

  /// Reconstructs a [CapturePhotoResult] view for existing inspector/colorimetry bridges.
  CapturePhotoResult toCapturePhotoResult() {
    return CapturePhotoResult(
      jpegPath: primaryPath,
      oemJpegPath: oemPath,
      dngPath: dngPath,
      mediaStoreJpegUri: mediaStoreUri,
      mediaStoreDngUri: mediaStoreDngUri,
      cameraId: cameraId,
      iso: iso,
      exposureTimeNs: exposureTimeNs,
      outputWidth: width,
      outputHeight: height,
      rustIspActive: rustIspActive,
      portraitDepthActive: isPortrait,
      solvedCctKelvin: solvedCctKelvin,
      rawHistogram32: rawHistogram32,
      centerLabD50: centerLabD50,
      colorSpaceTag: colorSpaceTag,
    );
  }

  ZameraMediaItem copyWith({
    String? id,
    ZameraMediaKind? kind,
    DateTime? createdAt,
    String? primaryPath,
    String? oemPath,
    String? dngPath,
    String? mediaStoreUri,
    String? mediaStoreDngUri,
    String? cameraId,
    int? width,
    int? height,
    int? iso,
    int? exposureTimeNs,
    double? solvedCctKelvin,
    String? colorSpaceTag,
    bool? rustIspActive,
    bool? isPortrait,
    double? portraitAperture,
    int? portraitLightingIndex,
    double? portraitLightIntensity,
    double? portraitFocusX,
    double? portraitFocusY,
    double? portraitSubjectRadiusRatio,
    List<double>? rawHistogram32,
    List<double>? centerLabD50,
    int? durationMs,
    int? fps,
    double? bitrateMbps,
    String? codec,
    String? videoProfile,
    String? colorStandard,
    String? colorTransfer,
    int? droppedFrames,
    int? fileSizeBytes,
    bool? hasWhiteOutline,
    String? sourceMediaId,
    bool? isFavorite,
  }) {
    return ZameraMediaItem(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      createdAt: createdAt ?? this.createdAt,
      primaryPath: primaryPath ?? this.primaryPath,
      oemPath: oemPath ?? this.oemPath,
      dngPath: dngPath ?? this.dngPath,
      mediaStoreUri: mediaStoreUri ?? this.mediaStoreUri,
      mediaStoreDngUri: mediaStoreDngUri ?? this.mediaStoreDngUri,
      cameraId: cameraId ?? this.cameraId,
      width: width ?? this.width,
      height: height ?? this.height,
      iso: iso ?? this.iso,
      exposureTimeNs: exposureTimeNs ?? this.exposureTimeNs,
      solvedCctKelvin: solvedCctKelvin ?? this.solvedCctKelvin,
      colorSpaceTag: colorSpaceTag ?? this.colorSpaceTag,
      rustIspActive: rustIspActive ?? this.rustIspActive,
      isPortrait: isPortrait ?? this.isPortrait,
      portraitAperture: portraitAperture ?? this.portraitAperture,
      portraitLightingIndex:
          portraitLightingIndex ?? this.portraitLightingIndex,
      portraitLightIntensity:
          portraitLightIntensity ?? this.portraitLightIntensity,
      portraitFocusX: portraitFocusX ?? this.portraitFocusX,
      portraitFocusY: portraitFocusY ?? this.portraitFocusY,
      portraitSubjectRadiusRatio:
          portraitSubjectRadiusRatio ?? this.portraitSubjectRadiusRatio,
      rawHistogram32: rawHistogram32 ?? this.rawHistogram32,
      centerLabD50: centerLabD50 ?? this.centerLabD50,
      durationMs: durationMs ?? this.durationMs,
      fps: fps ?? this.fps,
      bitrateMbps: bitrateMbps ?? this.bitrateMbps,
      codec: codec ?? this.codec,
      videoProfile: videoProfile ?? this.videoProfile,
      colorStandard: colorStandard ?? this.colorStandard,
      colorTransfer: colorTransfer ?? this.colorTransfer,
      droppedFrames: droppedFrames ?? this.droppedFrames,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      hasWhiteOutline: hasWhiteOutline ?? this.hasWhiteOutline,
      sourceMediaId: sourceMediaId ?? this.sourceMediaId,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  factory ZameraMediaItem.fromPhotoCapture(
    CapturePhotoResult res, {
    String? id,
    DateTime? createdAt,
    bool isPortrait = false,
    double? portraitAperture,
    int? portraitLightingIndex,
    double? portraitLightIntensity,
    Offset? focusTapNorm,
    double? portraitSubjectRadiusRatio,
  }) {
    final now = createdAt ?? DateTime.now();
    final path = res.jpegPath ?? res.oemJpegPath ?? res.dngPath ?? '';
    return ZameraMediaItem(
      id: id ?? 'pho_${now.microsecondsSinceEpoch}_${++_idSequence}',
      kind: ZameraMediaKind.photo,
      createdAt: now,
      primaryPath: path,
      oemPath: res.oemJpegPath,
      dngPath: res.dngPath,
      mediaStoreUri: res.mediaStoreJpegUri ?? res.mediaStoreDngUri,
      mediaStoreDngUri: res.mediaStoreDngUri,
      cameraId: res.cameraId,
      width: res.outputWidth,
      height: res.outputHeight,
      iso: res.iso,
      exposureTimeNs: res.exposureTimeNs,
      solvedCctKelvin: res.solvedCctKelvin,
      colorSpaceTag: res.colorSpaceTag,
      rustIspActive: res.rustIspActive,
      isPortrait: isPortrait || res.portraitDepthActive,
      portraitAperture: portraitAperture,
      portraitLightingIndex: portraitLightingIndex,
      portraitLightIntensity: portraitLightIntensity,
      portraitFocusX: focusTapNorm?.dx,
      portraitFocusY: focusTapNorm?.dy,
      portraitSubjectRadiusRatio: portraitSubjectRadiusRatio,
      rawHistogram32: res.rawHistogram32,
      centerLabD50: res.centerLabD50,
    );
  }

  factory ZameraMediaItem.fromVideoRecording(
    ZameraVideoRecordingResult res, {
    String? id,
    DateTime? createdAt,
    String cameraId = '2',
  }) {
    final now = createdAt ?? DateTime.now();
    return ZameraMediaItem(
      id: id ?? 'vid_${now.microsecondsSinceEpoch}_${++_idSequence}',
      kind: ZameraMediaKind.video,
      createdAt: now,
      primaryPath: res.videoPath,
      mediaStoreUri: res.mediaStoreUri,
      cameraId: cameraId,
      width: res.width,
      height: res.height,
      durationMs: res.durationMs,
      fps: res.fps,
      bitrateMbps: res.bitrateMbps,
      codec: res.codec,
      videoProfile: res.profile,
      colorStandard: res.colorStandard,
      colorTransfer: res.colorTransfer,
      droppedFrames: res.droppedFrames,
      fileSizeBytes: res.fileSizeBytes,
    );
  }

  factory ZameraMediaItem.fromStickerCutout({
    required String pngPath,
    String? mediaStoreUri,
    int? width,
    int? height,
    bool hasWhiteOutline = false,
    String? sourceMediaId,
    String? id,
    DateTime? createdAt,
  }) {
    final now = createdAt ?? DateTime.now();
    return ZameraMediaItem(
      id: id ?? 'stk_${now.microsecondsSinceEpoch}_${++_idSequence}',
      kind: ZameraMediaKind.sticker,
      createdAt: now,
      primaryPath: pngPath,
      mediaStoreUri: mediaStoreUri,
      width: width,
      height: height,
      hasWhiteOutline: hasWhiteOutline,
      sourceMediaId: sourceMediaId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kind': kind.name,
      'createdAtMs': createdAt.millisecondsSinceEpoch,
      'primaryPath': primaryPath,
      if (oemPath != null) 'oemPath': oemPath,
      if (dngPath != null) 'dngPath': dngPath,
      if (mediaStoreUri != null) 'mediaStoreUri': mediaStoreUri,
      if (mediaStoreDngUri != null) 'mediaStoreDngUri': mediaStoreDngUri,
      'cameraId': cameraId,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (iso != null) 'iso': iso,
      if (exposureTimeNs != null) 'exposureTimeNs': exposureTimeNs,
      if (solvedCctKelvin != null) 'solvedCctKelvin': solvedCctKelvin,
      if (colorSpaceTag != null) 'colorSpaceTag': colorSpaceTag,
      'rustIspActive': rustIspActive,
      'isPortrait': isPortrait,
      if (portraitAperture != null) 'portraitAperture': portraitAperture,
      if (portraitLightingIndex != null)
        'portraitLightingIndex': portraitLightingIndex,
      if (portraitLightIntensity != null)
        'portraitLightIntensity': portraitLightIntensity,
      if (portraitFocusX != null) 'portraitFocusX': portraitFocusX,
      if (portraitFocusY != null) 'portraitFocusY': portraitFocusY,
      if (portraitSubjectRadiusRatio != null)
        'portraitSubjectRadiusRatio': portraitSubjectRadiusRatio,
      if (rawHistogram32 != null) 'rawHistogram32': rawHistogram32,
      if (centerLabD50 != null) 'centerLabD50': centerLabD50,
      if (durationMs != null) 'durationMs': durationMs,
      if (fps != null) 'fps': fps,
      if (bitrateMbps != null) 'bitrateMbps': bitrateMbps,
      if (codec != null) 'codec': codec,
      if (videoProfile != null) 'videoProfile': videoProfile,
      if (colorStandard != null) 'colorStandard': colorStandard,
      if (colorTransfer != null) 'colorTransfer': colorTransfer,
      if (droppedFrames != null) 'droppedFrames': droppedFrames,
      if (fileSizeBytes != null) 'fileSizeBytes': fileSizeBytes,
      'hasWhiteOutline': hasWhiteOutline,
      if (sourceMediaId != null) 'sourceMediaId': sourceMediaId,
      'isFavorite': isFavorite,
    };
  }

  factory ZameraMediaItem.fromJson(Map<Object?, Object?> map) {
    final createdMs = (map['createdAtMs'] as num?)?.toInt();
    return ZameraMediaItem(
      id: map['id']?.toString() ??
          'item_${DateTime.now().microsecondsSinceEpoch}',
      kind: ZameraMediaKind.fromName(map['kind']?.toString()),
      createdAt: createdMs != null
          ? DateTime.fromMillisecondsSinceEpoch(createdMs)
          : DateTime.now(),
      primaryPath: map['primaryPath']?.toString() ?? '',
      oemPath: map['oemPath']?.toString(),
      dngPath: map['dngPath']?.toString(),
      mediaStoreUri: map['mediaStoreUri']?.toString(),
      mediaStoreDngUri: map['mediaStoreDngUri']?.toString(),
      cameraId: map['cameraId']?.toString() ?? '2',
      width: (map['width'] as num?)?.toInt(),
      height: (map['height'] as num?)?.toInt(),
      iso: (map['iso'] as num?)?.toInt(),
      exposureTimeNs: (map['exposureTimeNs'] as num?)?.toInt(),
      solvedCctKelvin: (map['solvedCctKelvin'] as num?)?.toDouble(),
      colorSpaceTag: map['colorSpaceTag']?.toString(),
      rustIspActive: map['rustIspActive'] == true,
      isPortrait: map['isPortrait'] == true,
      portraitAperture: (map['portraitAperture'] as num?)?.toDouble(),
      portraitLightingIndex: (map['portraitLightingIndex'] as num?)?.toInt(),
      portraitLightIntensity:
          (map['portraitLightIntensity'] as num?)?.toDouble(),
      portraitFocusX: (map['portraitFocusX'] as num?)?.toDouble(),
      portraitFocusY: (map['portraitFocusY'] as num?)?.toDouble(),
      portraitSubjectRadiusRatio:
          (map['portraitSubjectRadiusRatio'] as num?)?.toDouble(),
      rawHistogram32: (map['rawHistogram32'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(growable: false),
      centerLabD50: (map['centerLabD50'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(growable: false),
      durationMs: (map['durationMs'] as num?)?.toInt(),
      fps: (map['fps'] as num?)?.toInt(),
      bitrateMbps: (map['bitrateMbps'] as num?)?.toDouble(),
      codec: map['codec']?.toString(),
      videoProfile: map['videoProfile']?.toString(),
      colorStandard: map['colorStandard']?.toString(),
      colorTransfer: map['colorTransfer']?.toString(),
      droppedFrames: (map['droppedFrames'] as num?)?.toInt(),
      fileSizeBytes: (map['fileSizeBytes'] as num?)?.toInt(),
      hasWhiteOutline: map['hasWhiteOutline'] == true,
      sourceMediaId: map['sourceMediaId']?.toString(),
      isFavorite: map['isFavorite'] == true,
    );
  }
}
