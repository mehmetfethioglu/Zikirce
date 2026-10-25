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
  static const int _expectedDbUserVersion = 20261025;
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

      bool needsCopy = !dbFile.existsSync() || dbFile.lengthSync() != assetBytes.length;
      if (!needsCopy) {
        try {
          final probeDb = sql.sqlite3.open(dbPath);
          final res = probeDb.select('PRAGMA user_version;');
          final currentVer = res.isNotEmpty ? (res.first['user_version'] as int? ?? 0) : 0;
          probeDb.dispose();
          if (currentVer != _expectedDbUserVersion) {
            needsCopy = true;
          }
        } catch (_) {
          needsCopy = true;
        }
      }

      if (needsCopy) {
        debugPrint('[AudioSyncService] Updating ZikirceAudioSync.db (${assetBytes.length} bytes, v$_expectedDbUserVersion) from assets...');
        await dbFile.writeAsBytes(assetBytes, flush: true);
        _ayahCache.clear();
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

      final rawList = <WordTimestamp>[];
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

        rawList.add(WordTimestamp(
          surahId: r['SurahId'] as int? ?? surahId,
          ayahId: r['AyahId'] as int? ?? ayahId,
          pageId: r['PageId'] as int? ?? 1,
          wordOrder: r['WordOrder'] as int? ?? (i + 1),
          startTime: start,
          endTime: end,
        ));
      }

      final list = _normalizeAyahWordOrders(surahId, ayahId, rawList);

      // Safe split for consecutive words with identical start times in Diyanet DB
      // (e.g. short particle + main word like "وَلَا الضَّٓالّٖينَ", "لَا رَيْبَ")
      // Never exceeds nextGroupStart and caps short particle slice at 450ms.
      int idx = 0;
      while (idx < list.length) {
        int next = idx;
        while (next + 1 < list.length &&
            (list[next + 1].startTime - list[idx].startTime).abs() < 15) {
          next++;
        }
        if (next > idx) {
          final count = next - idx + 1;
          final groupStart = list[idx].startTime;
          final nextGroupStart = (next + 1 < list.length)
              ? list[next + 1].startTime
              : (groupStart + (count * 450.0));
          final availableSpan =
              (nextGroupStart - groupStart).clamp(40.0, 30000.0);
          final slice = (availableSpan / count).clamp(20.0, 450.0);
          for (int k = 0; k < count; k++) {
            final computedStart = groupStart + (k * slice);
            final computedEnd = (k == count - 1)
                ? nextGroupStart
                : (groupStart + ((k + 1) * slice));
            list[idx + k] = WordTimestamp(
              surahId: list[idx + k].surahId,
              ayahId: list[idx + k].ayahId,
              pageId: list[idx + k].pageId,
              wordOrder: list[idx + k].wordOrder,
              startTime: computedStart,
              endTime: computedEnd,
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

  /// Aligns the 6 known compound-token verses in Diyanet's DB and fills any skipped intermediate WordOrder
  static List<WordTimestamp> _normalizeAyahWordOrders(
    int surahId,
    int ayahId,
    List<WordTimestamp> raw,
  ) {
    if (raw.isEmpty) return raw;
    final pId = raw.first.pageId;

    // 1. Handle the 6 verses where Diyanet DB merged/split a vocative or waqf token relative to Uthmani text
    if (surahId == 15 && ayahId == 95 && raw.length == 2) {
      return [
        ...raw,
        WordTimestamp(
          surahId: 15,
          ayahId: 95,
          pageId: pId,
          wordOrder: 3,
          startTime: 2450.0,
          endTime: 4800.0,
        ),
      ];
    }
    if ((surahId == 27 && ayahId == 9 && raw.length == 6) ||
        (surahId == 64 && ayahId == 14 && raw.length == 18)) {
      final firstStart = raw.first.startTime;
      return [
        WordTimestamp(
          surahId: surahId,
          ayahId: ayahId,
          pageId: pId,
          wordOrder: 1,
          startTime: 0.0,
          endTime: firstStart > 0 ? firstStart : 600.0,
        ),
        for (final item in raw)
          WordTimestamp(
            surahId: item.surahId,
            ayahId: item.ayahId,
            pageId: item.pageId,
            wordOrder: item.wordOrder + 1,
            startTime: item.startTime,
            endTime: item.endTime,
          ),
      ];
    }
    if ((surahId == 33 && ayahId == 56 && raw.length == 13) ||
        (surahId == 37 && ayahId == 102 && raw.length == 27)) {
      final splitOrder = (surahId == 33) ? 7 : 18;
      final out = <WordTimestamp>[];
      for (final item in raw) {
        if (item.wordOrder < splitOrder) {
          out.add(item);
        } else if (item.wordOrder == splitOrder) {
          out.add(WordTimestamp(
            surahId: surahId,
            ayahId: ayahId,
            pageId: pId,
            wordOrder: splitOrder,
            startTime: item.startTime,
            endTime: item.startTime + 420.0,
          ));
          out.add(WordTimestamp(
            surahId: surahId,
            ayahId: ayahId,
            pageId: pId,
            wordOrder: splitOrder + 1,
            startTime: item.startTime + 420.0,
            endTime: item.endTime,
          ));
        } else {
          out.add(WordTimestamp(
            surahId: surahId,
            ayahId: ayahId,
            pageId: pId,
            wordOrder: item.wordOrder + 1,
            startTime: item.startTime,
            endTime: item.endTime,
          ));
        }
      }
      return out;
    }
    if (surahId == 2 && ayahId == 235 && raw.length == 48) {
      final out = <WordTimestamp>[];
      for (final item in raw) {
        if (item.wordOrder < 27) {
          out.add(item);
        } else if (item.wordOrder == 27) {
          continue; // extra pause entry at 31152ms before word 27 (وَلَا تَعْزِمُوا at 34210ms)
        } else {
          out.add(WordTimestamp(
            surahId: surahId,
            ayahId: ayahId,
            pageId: pId,
            wordOrder: item.wordOrder - 1,
            startTime: item.startTime,
            endTime: item.endTime,
          ));
        }
      }
      return out;
    }

    // 2. Fill any skipped intermediate WordOrder (e.g. 4:78, 7:196, 18:49, 27:36, 75:27, etc.)
    final filled = <WordTimestamp>[];
    for (int i = 0; i < raw.length; i++) {
      final curr = raw[i];
      if (i > 0) {
        final prev = raw[i - 1];
        final gapOrders = curr.wordOrder - prev.wordOrder;
        if (gapOrders > 1) {
          final timeSpan = (curr.startTime - prev.startTime).clamp(80.0, 30000.0);
          for (int m = 1; m < gapOrders; m++) {
            final ratio = m / gapOrders;
            final interpStart = prev.startTime + (timeSpan * ratio);
            filled.add(WordTimestamp(
              surahId: surahId,
              ayahId: ayahId,
              pageId: pId,
              wordOrder: prev.wordOrder + m,
              startTime: interpStart,
              endTime: prev.startTime + (timeSpan * ((m + 1) / gapOrders)),
            ));
          }
        }
      }
      filled.add(curr);
    }
    return filled;
  }

  /// Gets the currently active word index based on playback milliseconds (High-performance in-memory search)
  static int getActiveWordOrder(
    int surahId,
    int ayahId,
    double currentMs, {
    int? renderedWordCount,
  }) {
    final timestamps = getAyahTimestamps(surahId, ayahId);
    if (timestamps.isEmpty) return 0;

    int matchedIdx = 0;
    for (int i = timestamps.length - 1; i >= 0; i--) {
      if (currentMs >= timestamps[i].startTime) {
        matchedIdx = i;
        break;
      }
    }

    final rawOrder = timestamps[matchedIdx].wordOrder;
    if (renderedWordCount != null && renderedWordCount > 0) {
      return rawOrder.clamp(1, renderedWordCount);
    }
    return rawOrder;
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
