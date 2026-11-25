import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'native_document_restorer.dart';

/// Serialized manifest stored alongside a page's transparent ink alpha-mask PNG.
@immutable
class OpticalMaskEntry {
  final String filePath;
  final int pageIndex;
  final String maskImagePath;
  final int imageWidth;
  final int imageHeight;
  final int columnCount;
  final double detectedSkewDeg;
  final List<OpticalWordBlob> wordBlobs;
  final int lastAccessEpochMs;

  const OpticalMaskEntry({
    required this.filePath,
    required this.pageIndex,
    required this.maskImagePath,
    required this.imageWidth,
    required this.imageHeight,
    required this.columnCount,
    required this.detectedSkewDeg,
    required this.wordBlobs,
    required this.lastAccessEpochMs,
  });

  Map<String, dynamic> toJson() => {
        'filePath': filePath,
        'pageIndex': pageIndex,
        'maskImagePath': maskImagePath,
        'imageWidth': imageWidth,
        'imageHeight': imageHeight,
        'columnCount': columnCount,
        'detectedSkewDeg': detectedSkewDeg,
        'wordBlobs': wordBlobs.map((b) => b.toJson()).toList(),
        'lastAccessEpochMs': lastAccessEpochMs,
      };

  factory OpticalMaskEntry.fromJson(Map<String, dynamic> json) {
    final rawBlobs = json['wordBlobs'] as List<dynamic>? ?? const [];
    return OpticalMaskEntry(
      filePath: (json['filePath'] as String?) ?? '',
      pageIndex: (json['pageIndex'] as num?)?.toInt() ?? 0,
      maskImagePath: (json['maskImagePath'] as String?) ?? '',
      imageWidth: (json['imageWidth'] as num?)?.toInt() ?? 0,
      imageHeight: (json['imageHeight'] as num?)?.toInt() ?? 0,
      columnCount: (json['columnCount'] as num?)?.toInt() ?? 1,
      detectedSkewDeg: (json['detectedSkewDeg'] as num?)?.toDouble() ?? 0.0,
      wordBlobs: rawBlobs
          .whereType<Map<String, dynamic>>()
          .map(OpticalWordBlob.fromJson)
          .toList(),
      lastAccessEpochMs: (json['lastAccessEpochMs'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Manages optical transparent alpha-mask PNGs & word blobs on disk under a strict
/// **150 MB Disk LRU ceiling**, keeping permanent OCR text in SQLite untouched.
class OpticalMaskCacheService {
  /// Default 150 MiB ceiling for visual optical alpha masks.
  static const int defaultMaxCacheBytes = 150 * 1024 * 1024;

  final int maxCacheBytes;
  final Directory? overrideRootDir;

  const OpticalMaskCacheService({
    this.maxCacheBytes = defaultMaxCacheBytes,
    this.overrideRootDir,
  });

  Future<Directory> _resolveCacheDir() async {
    if (overrideRootDir != null) {
      if (!await overrideRootDir!.exists()) {
        await overrideRootDir!.create(recursive: true);
      }
      return overrideRootDir!;
    }
    final appSupport = await getApplicationSupportDirectory();
    final dir = Directory(p.join(appSupport.path, 'optical_masks'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static String _pageKey(String filePath, int pageIndex) {
    final safeHash = filePath.hashCode.toUnsigned(32).toRadixString(16);
    return 'opt_${safeHash}_p$pageIndex';
  }

  /// Stores the transparent alpha-mask PNG & word-blob manifest, then trims LRU excess.
  Future<OpticalMaskEntry?> putMask({
    required String filePath,
    required int pageIndex,
    required DocumentRestorationResult restoration,
    DateTime? now,
  }) async {
    if (!restoration.isValid || restoration.alphaMaskPngBytes.isEmpty) {
      return null;
    }

    try {
      final dir = await _resolveCacheDir();
      final key = _pageKey(filePath, pageIndex);
      final maskPath = p.join(dir.path, '$key.png');
      final manifestPath = p.join(dir.path, '$key.json');

      final maskFile = File(maskPath);
      await maskFile.writeAsBytes(restoration.alphaMaskPngBytes, flush: true);

      final accessMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
      final entry = OpticalMaskEntry(
        filePath: filePath,
        pageIndex: pageIndex,
        maskImagePath: maskPath,
        imageWidth: restoration.width,
        imageHeight: restoration.height,
        columnCount: restoration.columnCount,
        detectedSkewDeg: restoration.detectedSkewDeg,
        wordBlobs: restoration.wordBlobs,
        lastAccessEpochMs: accessMs,
      );

      final manifestFile = File(manifestPath);
      await manifestFile.writeAsString(jsonEncode(entry.toJson()), flush: true);

      await _evictLruIfNeeded(dir);
      return entry;
    } catch (e) {
      debugPrint('OpticalMaskCacheService putMask error: $e');
      return null;
    }
  }

  /// Loads cached optical mask manifest & updates LRU timestamp if still present.
  Future<OpticalMaskEntry?> getMask({
    required String filePath,
    required int pageIndex,
    DateTime? now,
  }) async {
    try {
      final dir = await _resolveCacheDir();
      final key = _pageKey(filePath, pageIndex);
      final manifestFile = File(p.join(dir.path, '$key.json'));
      final maskFile = File(p.join(dir.path, '$key.png'));
      if (!await manifestFile.exists() || !await maskFile.exists()) {
        return null;
      }

      final raw = await manifestFile.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final parsed = OpticalMaskEntry.fromJson(decoded);

      final updated = OpticalMaskEntry(
        filePath: parsed.filePath,
        pageIndex: parsed.pageIndex,
        maskImagePath: parsed.maskImagePath,
        imageWidth: parsed.imageWidth,
        imageHeight: parsed.imageHeight,
        columnCount: parsed.columnCount,
        detectedSkewDeg: parsed.detectedSkewDeg,
        wordBlobs: parsed.wordBlobs,
        lastAccessEpochMs: (now ?? DateTime.now()).millisecondsSinceEpoch,
      );
      await manifestFile.writeAsString(
        jsonEncode(updated.toJson()),
        flush: true,
      );
      return updated;
    } catch (e) {
      debugPrint('OpticalMaskCacheService getMask error: $e');
      return null;
    }
  }

  /// Computes total bytes currently occupied inside the optical mask cache directory.
  Future<int> currentCacheBytes() async {
    try {
      final dir = await _resolveCacheDir();
      int total = 0;
      await for (final entity in dir.list()) {
        if (entity is File) {
          total += await entity.length();
        }
      }
      return total;
    } catch (e) {
      debugPrint('OpticalMaskCacheService currentCacheBytes error: $e');
      return 0;
    }
  }

  Future<void> _evictLruIfNeeded(Directory dir) async {
    try {
      final entries = <({File manifest, File? mask, int accessMs, int bytes})>[];
      int totalBytes = 0;

      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final len = await entity.length();
        totalBytes += len;
        if (!entity.path.endsWith('.json')) continue;

        final pngPath =
            '${entity.path.substring(0, entity.path.length - 5)}.png';
        final pngFile = File(pngPath);
        final pngLen = await pngFile.exists() ? await pngFile.length() : 0;

        int accessMs = (await entity.lastModified()).millisecondsSinceEpoch;
        try {
          final decoded = jsonDecode(await entity.readAsString());
          if (decoded is Map<String, dynamic>) {
            accessMs =
                (decoded['lastAccessEpochMs'] as num?)?.toInt() ?? accessMs;
          }
        } catch (e) {
          debugPrint('OpticalMaskCacheService manifest read warning: $e');
        }

        entries.add((
          manifest: entity,
          mask: await pngFile.exists() ? pngFile : null,
          accessMs: accessMs,
          bytes: len + pngLen,
        ));
      }

      if (totalBytes <= maxCacheBytes) return;

      entries.sort((a, b) => a.accessMs.compareTo(b.accessMs));
      for (final item in entries) {
        if (totalBytes <= maxCacheBytes) break;
        if (item.mask != null && await item.mask!.exists()) {
          await item.mask!.delete();
        }
        if (await item.manifest.exists()) {
          await item.manifest.delete();
        }
        totalBytes -= item.bytes;
      }
    } catch (e) {
      debugPrint('OpticalMaskCacheService LRU eviction warning: $e');
    }
  }
}
