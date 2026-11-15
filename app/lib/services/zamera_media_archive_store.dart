import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zamera_capture/zamera_capture.dart';

import '../models/media_archive_item.dart';

/// Dependency-inverted persistence & archive contract for Zamera captured media.
abstract interface class MediaArchiveRepository implements Listenable {
  List<ZameraMediaItem> get items;

  ZameraMediaItem? get latestItem;

  Future<void> load();

  Future<void> addOrUpdate(ZameraMediaItem item);

  Future<void> toggleFavorite(String id);

  Future<void> remove(String id, {bool deleteDiskFiles = true});

  List<ZameraMediaItem> itemsForFilter(ZameraArchiveFilter filter);
}

/// Persistent `SharedPreferences`-backed archive store for photos, videos, and stickers.
class ZameraMediaArchiveStore extends ChangeNotifier
    implements MediaArchiveRepository {
  static const String defaultStorageKey = 'zamera_media_archive_v1';
  static const int maxRetainedEntries = 240;
  static const Duration _ioTimeout = Duration(seconds: 3);

  final String storageKey;
  final bool Function(String path) _fileExistsPredicate;
  final Future<bool> Function({String? filePath, String? mediaStoreUri})
      _deleteNativeAsset;

  List<ZameraMediaItem> _items = <ZameraMediaItem>[];
  bool _isLoaded = false;

  ZameraMediaArchiveStore({
    this.storageKey = defaultStorageKey,
    List<ZameraMediaItem>? initialItems,
    bool Function(String path)? fileExistsPredicate,
    Future<bool> Function({String? filePath, String? mediaStoreUri})?
        deleteNativeAsset,
  })  : _fileExistsPredicate =
            fileExistsPredicate ?? ((path) => File(path).existsSync()),
        _deleteNativeAsset =
            deleteNativeAsset ?? ZameraCapture.deleteMediaAsset {
    if (initialItems != null) {
      _items = List<ZameraMediaItem>.from(initialItems)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _isLoaded = true;
    }
  }

  bool get isLoaded => _isLoaded;

  @override
  List<ZameraMediaItem> get items => List.unmodifiable(_items);

  @override
  ZameraMediaItem? get latestItem => _items.isEmpty ? null : _items.first;

  @override
  List<ZameraMediaItem> itemsForFilter(ZameraArchiveFilter filter) {
    if (filter == ZameraArchiveFilter.all) return items;
    return _items.where(filter.matches).toList(growable: false);
  }

  @override
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(_ioTimeout);
      final rawJson = prefs.getString(storageKey);
      if (rawJson == null || rawJson.trim().isEmpty) {
        _isLoaded = true;
        notifyListeners();
        return;
      }
      final decoded = jsonDecode(rawJson);
      if (decoded is! List<dynamic>) {
        _isLoaded = true;
        notifyListeners();
        return;
      }
      final parsed = <ZameraMediaItem>[];
      var prunedAny = false;
      for (final entry in decoded) {
        if (entry is Map<Object?, Object?>) {
          final item = ZameraMediaItem.fromJson(entry);
          if (item.primaryPath.isNotEmpty &&
              _fileExistsPredicate(item.primaryPath)) {
            parsed.add(item);
          } else {
            prunedAny = true;
          }
        }
      }
      parsed.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (parsed.length > maxRetainedEntries) {
        parsed.removeRange(maxRetainedEntries, parsed.length);
        prunedAny = true;
      }
      _items = parsed;
      _isLoaded = true;
      notifyListeners();
      if (prunedAny) {
        await _persist();
      }
    } catch (e, st) {
      debugPrint('ZameraMediaArchiveStore.load error: $e\n$st');
      _isLoaded = true;
      notifyListeners();
    }
  }

  @override
  Future<void> addOrUpdate(ZameraMediaItem item) async {
    if (item.primaryPath.trim().isEmpty) return;
    final idx = _items.indexWhere((e) => e.id == item.id);
    if (idx >= 0) {
      _items[idx] = item;
    } else {
      _items.insert(0, item);
    }
    _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (_items.length > maxRetainedEntries) {
      _items.removeRange(maxRetainedEntries, _items.length);
    }
    notifyListeners();
    await _persist();
  }

  @override
  Future<void> toggleFavorite(String id) async {
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    _items[idx] = _items[idx].copyWith(isFavorite: !_items[idx].isFavorite);
    notifyListeners();
    await _persist();
  }

  @override
  Future<void> remove(String id, {bool deleteDiskFiles = true}) async {
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final target = _items.removeAt(idx);
    notifyListeners();
    await _persist();

    if (deleteDiskFiles) {
      try {
        await _deleteNativeAsset(
          filePath: target.primaryPath,
          mediaStoreUri: target.mediaStoreUri,
        );
        if (target.dngPath != null && target.dngPath!.isNotEmpty) {
          await _deleteNativeAsset(
            filePath: target.dngPath,
            mediaStoreUri: target.mediaStoreDngUri,
          );
        }
        if (target.oemPath != null &&
            target.oemPath!.isNotEmpty &&
            target.oemPath != target.primaryPath) {
          await _deleteNativeAsset(filePath: target.oemPath);
        }
      } catch (e, st) {
        debugPrint('ZameraMediaArchiveStore.remove disk error: $e\n$st');
      }
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(_ioTimeout);
      final encoded = jsonEncode(
        _items.map((e) => e.toJson()).toList(growable: false),
      );
      await prefs.setString(storageKey, encoded).timeout(_ioTimeout);
    } catch (e, st) {
      debugPrint('ZameraMediaArchiveStore._persist error: $e\n$st');
    }
  }
}
