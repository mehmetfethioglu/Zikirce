import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Bounded on-disk cache for signed Cloudflare R2 WebP recipe cover images.
///
/// Cache keys strip short-lived `?exp=...&sig=...` query tokens so previously
/// viewed recipe photos remain readable offline across URL renewals.
class RecipeImageDiskCache {
  static final RecipeImageDiskCache instance = RecipeImageDiskCache._internal();

  static const int maxCacheBytes = 60 * 1024 * 1024;
  static const Duration fetchTimeout = Duration(seconds: 12);

  final Map<String, Future<File?>> _inFlight = {};
  Directory? _cacheDir;
  int _writesSinceEvict = 0;

  RecipeImageDiskCache._internal();

  /// Derives a stable cache key by removing ephemeral query parameters.
  static String canonicalCacheKey(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return url.trim();
    return '${uri.scheme}://${uri.host}${uri.path}';
  }

  /// Resolves a deterministic filename under the cache directory for [signedUrl].
  static String cacheFileNameForUrl(String signedUrl) {
    final key = canonicalCacheKey(signedUrl);
    final digest = sha256.convert(utf8.encode(key)).toString().substring(0, 32);
    return '$digest.webp';
  }

  Future<Directory?> _ensureCacheDir() async {
    if (kIsWeb) return null;
    if (_cacheDir != null) return _cacheDir;
    try {
      final base = await getTemporaryDirectory();
      final dir = Directory(p.join(base.path, 'kilerce_recipe_img_cache'));
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      _cacheDir = dir;
      return dir;
    } catch (e) {
      debugPrint('RecipeImageDiskCache._ensureCacheDir error: $e');
      return null;
    }
  }

  Future<File?> getOrFetchFile(String signedUrl, {http.Client? client}) async {
    if (kIsWeb || signedUrl.trim().isEmpty) return null;
    final canonical = canonicalCacheKey(signedUrl);

    final dir = await _ensureCacheDir();
    if (dir == null) return null;

    final file = File(p.join(dir.path, cacheFileNameForUrl(signedUrl)));
    try {
      if (file.existsSync() && file.lengthSync() > 100) {
        return file;
      }
    } catch (e) {
      debugPrint('RecipeImageDiskCache stat error: $e');
    }

    final existingTask = _inFlight[canonical];
    if (existingTask != null) return existingTask;

    final future = _downloadToFile(signedUrl, file, client: client);
    _inFlight[canonical] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(canonical);
    }
  }

  Future<File?> _downloadToFile(
    String signedUrl,
    File targetFile, {
    http.Client? client,
  }) async {
    final ownClient = client == null;
    final activeClient = client ?? http.Client();
    try {
      final uri = Uri.tryParse(signedUrl);
      if (uri == null) return null;
      final resp = await activeClient.get(uri).timeout(fetchTimeout);
      if (resp.statusCode != 200 || resp.bodyBytes.length < 100) {
        return null;
      }

      final tmpFile = File('${targetFile.path}.tmp');
      await tmpFile.writeAsBytes(resp.bodyBytes, flush: true);
      await tmpFile.rename(targetFile.path);

      _writesSinceEvict += 1;
      if (_writesSinceEvict >= 25) {
        _writesSinceEvict = 0;
        await _evictIfOverBudget(targetFile.parent);
      }
      return targetFile;
    } catch (e) {
      debugPrint('RecipeImageDiskCache download failed ($signedUrl): $e');
      return null;
    } finally {
      if (ownClient) {
        activeClient.close();
      }
    }
  }

  Future<void> _evictIfOverBudget(Directory dir) async {
    try {
      final entries = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.webp'))
          .toList();
      int totalBytes = 0;
      final stats = <(File file, FileStat stat)>[];
      for (final file in entries) {
        final st = file.statSync();
        totalBytes += st.size;
        stats.add((file, st));
      }
      if (totalBytes <= maxCacheBytes) return;

      stats.sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
      for (final entry in stats) {
        if (totalBytes <= (maxCacheBytes * 0.8).round()) break;
        entry.$1.deleteSync();
        totalBytes -= entry.$2.size;
      }
    } catch (e) {
      debugPrint('RecipeImageDiskCache._evictIfOverBudget error: $e');
    }
  }
}
