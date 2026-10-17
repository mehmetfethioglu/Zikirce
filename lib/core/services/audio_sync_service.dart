import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import 'package:flutter/foundation.dart';

import 'ios_now_playing_service.dart';

class WordTimestamp {
  final int surahId;
  final int ayahId;
  final int pageId;
  final int wordOrder;
  final double startTime;
  final double endTime;

  WordTimestamp({
    required this.surahId,
    required this.ayahId,
    required this.pageId,
    required this.wordOrder,
    required this.startTime,
    required this.endTime,
  });
}

class VerseAudioInfo {
  final int pageId;
  final int surahId;
  final int ayahId;

  const VerseAudioInfo({
    required this.pageId,
    required this.surahId,
    required this.ayahId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VerseAudioInfo &&
          runtimeType == other.runtimeType &&
          surahId == other.surahId &&
          ayahId == other.ayahId;

  @override
  int get hashCode => surahId.hashCode ^ ayahId.hashCode;
}

class AudioSyncService {
  static sql.Database? _db;
  static final Map<String, List<WordTimestamp>> _ayahCache = {};

  /// Initializes the SQLite audio sync database by copying it from assets if needed.
  static Future<void> initialize() async {
    await configureAudioSession();
    if (_db != null) return;

    try {
      final docDir = await getApplicationDocumentsDirectory();
      final dbPath = p.join(docDir.path, 'ZikirceAudioSync.db');
      final dbFile = File(dbPath);

      final byteData = await rootBundle.load('assets/raw/ZikirceAudioSync.db');
      final assetBytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );

      // Copy or update if file doesn't exist or size differs
      if (!dbFile.existsSync() || dbFile.lengthSync() != assetBytes.length) {
        debugPrint('[AudioSyncService] Copying ZikirceAudioSync.db (${assetBytes.length} bytes) from assets...');
        await dbFile.writeAsBytes(assetBytes, flush: true);
      }

      _db = sql.sqlite3.open(dbPath);
      debugPrint('[AudioSyncService] Database loaded successfully from: $dbPath');
    } catch (e) {
      debugPrint('[AudioSyncService] Error initializing AudioSync database: $e');
    }
  }

  /// Configures the global audio session for reliable foreground & background playback on mobile devices
  static Future<void> configureAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      await session.setActive(true);
      await IosNowPlayingService.activateSession();
    } catch (e) {
      debugPrint('[AudioSyncService] configureAudioSession error: $e');
    }
  }

  /// Returns all distinct verses across the whole Quran
  static Future<List<VerseAudioInfo>> getAllDistinctVerses() async {
    await initialize();
    if (_db == null) return [];

    try {
      final stmt = _db!.prepare('''
        SELECT DISTINCT PageId, SurahId, AyahId 
        FROM AudioTimestamps 
        ORDER BY SurahId ASC, AyahId ASC;
      ''');
      final rows = stmt.select([]);
      stmt.dispose();

      return rows.map((r) => VerseAudioInfo(
        pageId: r['PageId'] as int? ?? 1,
        surahId: r['SurahId'] as int? ?? 1,
        ayahId: r['AyahId'] as int? ?? 1,
      )).toList();
    } catch (e) {
      debugPrint('[AudioSyncService] getAllDistinctVerses error: $e');
      return [];
    }
  }

  /// Returns distinct verses for a specific page (1 to 604)
  static Future<List<VerseAudioInfo>> getVersesByPage(int pageId) async {
    await initialize();
    if (_db == null) return [];

    try {
      final stmt = _db!.prepare('''
        SELECT DISTINCT PageId, SurahId, AyahId 
        FROM AudioTimestamps 
        WHERE PageId = ?
        ORDER BY SurahId ASC, AyahId ASC;
      ''');
      final rows = stmt.select([pageId]);
      stmt.dispose();

      return rows.map((r) => VerseAudioInfo(
        pageId: r['PageId'] as int? ?? pageId,
        surahId: r['SurahId'] as int? ?? 1,
        ayahId: r['AyahId'] as int? ?? 1,
      )).toList();
    } catch (e) {
      debugPrint('[AudioSyncService] getVersesByPage error: $e');
      return [];
    }
  }

  /// Gets start and end page for a juz (1 to 30)
  static (int startPage, int endPage) getJuzPageRange(int juzNumber) {
    if (juzNumber <= 1) return (1, 21);
    if (juzNumber >= 30) return (582, 604);
    final start = (juzNumber - 1) * 20 + 2;
    final end = juzNumber * 20 + 1;
    return (start, end);
  }

  /// Returns distinct verses for a specific juz (1 to 30)
  static Future<List<VerseAudioInfo>> getVersesByJuz(int juzNumber) async {
    await initialize();
    if (_db == null) return [];

    final (startPage, endPage) = getJuzPageRange(juzNumber);

    try {
      final stmt = _db!.prepare('''
        SELECT DISTINCT PageId, SurahId, AyahId 
        FROM AudioTimestamps 
        WHERE PageId >= ? AND PageId <= ?
        ORDER BY SurahId ASC, AyahId ASC;
      ''');
      final rows = stmt.select([startPage, endPage]);
      stmt.dispose();

      return rows.map((r) => VerseAudioInfo(
        pageId: r['PageId'] as int? ?? startPage,
        surahId: r['SurahId'] as int? ?? 1,
        ayahId: r['AyahId'] as int? ?? 1,
      )).toList();
    } catch (e) {
      debugPrint('[AudioSyncService] getVersesByJuz error: $e');
      return [];
    }
  }

  /// Gets all word timestamps for an ayah (with in-memory caching)
  static List<WordTimestamp> getAyahTimestamps(int surahId, int ayahId) {
    final cacheKey = '${surahId}_$ayahId';
    if (_ayahCache.containsKey(cacheKey)) {
      return _ayahCache[cacheKey]!;
    }

    if (_db == null) return [];

    try {
      final stmt = _db!.prepare('''
        SELECT SurahId, AyahId, PageId, WordOrder, StartTime 
        FROM AudioTimestamps 
        WHERE SurahId = ? AND AyahId = ?
        ORDER BY WordOrder ASC;
      ''');
      final rows = stmt.select([surahId, ayahId]);
      stmt.dispose();

      final list = <WordTimestamp>[];
      for (int i = 0; i < rows.length; i++) {
        final r = rows[i];
        final start = (r['StartTime'] as num?)?.toDouble() ?? 0.0;
        double end;
        if (i < rows.length - 1) {
          final nextStart = (rows[i + 1]['StartTime'] as num?)?.toDouble() ?? (start + 1000.0);
          end = nextStart > start ? nextStart : (start + 1000.0);
        } else {
          end = start + 3000.0;
        }

        list.add(WordTimestamp(
          surahId: r['SurahId'] as int? ?? surahId,
          ayahId: r['AyahId'] as int? ?? ayahId,
          pageId: r['PageId'] as int? ?? 1,
          wordOrder: r['WordOrder'] as int? ?? (i + 1),
          startTime: start,
          endTime: end,
        ));
      }

      // Smooth interpolation for consecutive words with identical or near-identical start times
      // (e.g. compound particles like "يَٓا اَيُّهَا", "وَلَا الضَّٓالّٖينَ", "وَإِذْ قَالَ", "لَا تُوَاعِدُوهُنَّ")
      int idx = 0;
      while (idx < list.length) {
        int next = idx;
        while (next + 1 < list.length && (list[next + 1].startTime - list[idx].startTime).abs() < 40) {
          next++;
        }
        if (next > idx) {
          final count = next - idx + 1;
          final groupStart = list[idx].startTime;
          final nextGroupStart = (next + 1 < list.length)
              ? list[next + 1].startTime
              : (groupStart + (count * 800.0));
          final span = (nextGroupStart - groupStart).clamp(count * 250.0, 30000.0);
          final slice = span / count;
          for (int k = 0; k < count; k++) {
            list[idx + k] = WordTimestamp(
              surahId: list[idx + k].surahId,
              ayahId: list[idx + k].ayahId,
              pageId: list[idx + k].pageId,
              wordOrder: list[idx + k].wordOrder,
              startTime: groupStart + (k * slice),
              endTime: groupStart + ((k + 1) * slice),
            );
          }
          idx = next + 1;
        } else {
          idx++;
        }
      }

      if (list.isNotEmpty) {
        _ayahCache[cacheKey] = list;
      }
      return list;
    } catch (e) {
      debugPrint('[AudioSyncService] getAyahTimestamps error: $e');
      return [];
    }
  }

  /// Gets the currently active word index based on playback milliseconds (High-performance in-memory search)
  static int getActiveWordOrder(int surahId, int ayahId, double currentMs) {
    final timestamps = getAyahTimestamps(surahId, ayahId);
    if (timestamps.isEmpty) return 0;

    // 1. Find the latest word whose StartTime <= currentMs
    for (int i = timestamps.length - 1; i >= 0; i--) {
      if (currentMs >= timestamps[i].startTime) {
        return timestamps[i].wordOrder;
      }
    }

    // Default to first word if playback just started
    return timestamps.first.wordOrder;
  }

  /// Gets specific word timestamp for an ayah
  static WordTimestamp? getWordTimestamp(int surahId, int ayahId, int wordOrder) {
    final timestamps = getAyahTimestamps(surahId, ayahId);
    if (timestamps.isEmpty) return null;

    try {
      return timestamps.firstWhere(
        (w) => w.wordOrder == wordOrder,
      );
    } catch (_) {
      return null;
    }
  }
}
