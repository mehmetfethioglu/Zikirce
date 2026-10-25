import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

class TafseerSourceInfo {
  final String id;
  final String title;
  final String shortTitle;
  final String author;
  final String eraBadge;
  final String description;
  final String fileName;
  final String sizeLabel;
  final double approxMb;
  final bool isJsonEdition;
  final String? jsonEditionSlug;

  const TafseerSourceInfo({
    required this.id,
    required this.title,
    required this.shortTitle,
    required this.author,
    required this.eraBadge,
    required this.description,
    required this.fileName,
    required this.sizeLabel,
    required this.approxMb,
    this.isJsonEdition = false,
    this.jsonEditionSlug,
  });

  List<String> get downloadUrls {
    if (isJsonEdition && jsonEditionSlug != null) {
      return [
        'https://cdn.jsdelivr.net/gh/fawazahmed0/quran-api@1/editions/$jsonEditionSlug.min.json',
        'https://raw.githubusercontent.com/fawazahmed0/quran-api/1/editions/$jsonEditionSlug.min.json',
      ];
    }
    return [
      'https://raw.githubusercontent.com/mehmetfethioglu/zikirce-indir/e737923/tafsirs/$fileName',
      'https://raw.githubusercontent.com/mehmetfethioglu/zikirce-indir/main/tafsirs/$fileName?v=2',
      'https://mehmetfethioglu.github.io/zikirce-indir/tafsirs/$fileName?v=2',
    ];
  }
}

class TafseerEntryResult {
  final TafseerSourceInfo source;
  final int surahId;
  final int startVerse;
  final int endVerse;
  final String title;
  final String mealText;
  final String tefsirText;

  const TafseerEntryResult({
    required this.source,
    required this.surahId,
    required this.startVerse,
    required this.endVerse,
    required this.title,
    required this.mealText,
    required this.tefsirText,
  });

  bool get isVerseRange => endVerse > startVerse;
  String get rangeLabel =>
      isVerseRange ? '$startVerse-$endVerse. Âyetler' : '$startVerse. Âyet';
}

class TafseerService {
  static final TafseerService _instance = TafseerService._internal();
  factory TafseerService() => _instance;
  TafseerService._internal();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 120),
    ),
  );

  static const List<TafseerSourceInfo> availableSources = [
    TafseerSourceInfo(
      id: 'kuran_yolu',
      title: 'Kur\'ân Yolu Türkçe Meâl ve Tefsir',
      shortTitle: 'Kur\'ân Yolu (Diyanet)',
      author: 'Diyanet İşleri Başkanlığı Heyeti',
      eraBadge: 'Diyanet • 5 Cilt Tam Metin',
      description:
          'Prof. Dr. Hayrettin Karaman, Prof. Dr. Mustafa Çağrıcı, Prof. Dr. İ. Kâfi Dönmez ve Prof. Dr. Sadrettin Gümüş tarafından hazırlanan 5 ciltlik tam metin tefsir.',
      fileName: 'kuran_yolu.db.gz',
      sizeLabel: '2.5 MB',
      approxMb: 2.5,
    ),
    TafseerSourceInfo(
      id: 'envarut_tenzil',
      title: 'Envârü\'t-Tenzîl ve Esrârü\'t-Te\'vîl',
      shortTitle: 'Beyzâvî Tefsiri',
      author: 'Kâdı Nâsırüddîn el-Beyzâvî (v. 685/1286)',
      eraBadge: 'Klasik • Dirâyet & Belâgat',
      description:
          'Osmanlı medreselerinde asırlarca okutulan, âyetlerin dil inceliklerini ve kelâmî nüktelerini açıklayan klasik tefsir.',
      fileName: 'envarut_tenzil.db.gz',
      sizeLabel: '1.8 MB',
      approxMb: 1.8,
    ),
    TafseerSourceInfo(
      id: 'tevilatul_kuran',
      title: 'Te\'vîlâtü\'l-Kur\'ân',
      shortTitle: 'İmam Mâtürîdî',
      author: 'İmam Ebû Mansûr el-Mâtürîdî (v. 333/944)',
      eraBadge: 'Klasik • Ehl-i Sünnet Kelâmı',
      description:
          'Mâtürîdiyye kelâm mektebinin kurucusu İmam Mâtürîdî\'nin akıl ve nakil dengesini esas alan tam metin dirâyet tefsiri.',
      fileName: 'tevilatul_kuran.db.gz',
      sizeLabel: '5.5 MB',
      approxMb: 5.5,
    ),
    TafseerSourceInfo(
      id: 'el_kessaf',
      title: 'el-Keşşâf an Hakâikı\'t-Tenzîl',
      shortTitle: 'el-Keşşâf (Zemahşerî)',
      author: 'Cârullah ez-Zemahşerî (v. 538/1144)',
      eraBadge: 'Klasik • Dil & İ\'câz',
      description:
          'Kur\'ân-ı Kerîm\'in belâgatını, fesâhatini ve edebî نظم (nazım) inceliklerini ortaya koyan klasik dil ve üslup tefsiri.',
      fileName: 'el_kessaf.db.gz',
      sizeLabel: '3.5 MB',
      approxMb: 3.5,
    ),
    TafseerSourceInfo(
      id: 'mefatihul_gayb',
      title: 'Mefâtîhu\'l-Gayb (Tefsîr-i Kebîr)',
      shortTitle: 'Tefsîr-i Kebîr (Râzî)',
      author: 'Fahreddin er-Râzî (v. 606/1210)',
      eraBadge: 'Klasik • Hikmet & Tefekkür',
      description:
          'Âyetler arasındaki münasebetleri, kelâmî ve kevni meseleleri derinlikli başlıklar halinde tahlil eden ansiklopedik tefsir.',
      fileName: 'mefatihul_gayb.db.gz',
      sizeLabel: '10.0 MB',
      approxMb: 10.0,
    ),
  ];

  final Map<String, sql.Database> _openDbs = {};
  final Map<String, Map<String, String>> _jsonCache = {};
  final Set<String> _downloadingIds = {};

  /// Initializes the tafseer storage directory and cleans up any legacy 0-byte db files.
  static Future<void> initialize() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final tafsirsDir = Directory(p.join(docDir.path, 'tafsirs'));
      if (!await tafsirsDir.exists()) {
        await tafsirsDir.create(recursive: true);
      }
      final legacyZeroFile = File(p.join(docDir.path, 'TevilatulKuran.db'));
      if (await legacyZeroFile.exists() && await legacyZeroFile.length() == 0) {
        await legacyZeroFile.delete();
      }
    } catch (e) {
      debugPrint('[TafseerService] initialize notice: $e');
    }
  }

  static TafseerSourceInfo getSourceInfo(String id) {
    return availableSources.firstWhere(
      (s) => s.id == id,
      orElse: () => availableSources.first,
    );
  }

  Future<String> _getTafsirsDirPath() async {
    final docDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docDir.path, 'tafsirs'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  Future<File> _getTargetFile(String sourceId) async {
    final info = getSourceInfo(sourceId);
    final dir = await _getTafsirsDirPath();
    final targetName =
        info.isJsonEdition ? '${info.id}.json' : '${info.id}_v2.db';
    return File(p.join(dir, targetName));
  }

  Future<bool> isDownloaded(String sourceId) async {
    final file = await _getTargetFile(sourceId);
    return file.existsSync() && file.lengthSync() > 10240;
  }

  Future<List<String>> getDownloadedSourceIds() async {
    final List<String> result = [];
    for (final src in availableSources) {
      if (await isDownloaded(src.id)) {
        result.add(src.id);
      }
    }
    return result;
  }

  bool isDownloading(String sourceId) => _downloadingIds.contains(sourceId);

  Future<bool> downloadSource(
    String sourceId, {
    void Function(double progress)? onProgress,
  }) async {
    if (_downloadingIds.contains(sourceId)) return false;
    _downloadingIds.add(sourceId);

    try {
      final info = getSourceInfo(sourceId);
      final targetFile = await _getTargetFile(sourceId);

      if (info.isJsonEdition) {
        for (final url in info.downloadUrls) {
          try {
            final response = await _dio.get<String>(
              url,
              options: Options(responseType: ResponseType.plain),
              onReceiveProgress: (received, total) {
                if (onProgress != null && total > 0) {
                  onProgress((received / total).clamp(0.0, 0.95));
                }
              },
            );
            if (response.statusCode == 200 && response.data != null) {
              final decoded =
                  jsonDecode(response.data!) as Map<String, dynamic>;
              final quranList = decoded['quran'] as List<dynamic>? ?? [];
              final Map<String, String> verseMap = {};
              for (final item in quranList) {
                if (item is Map<String, dynamic>) {
                  final ch = item['chapter'];
                  final v = item['verse'];
                  final txt = (item['text'] ?? '').toString().trim();
                  if (ch != null && v != null && txt.isNotEmpty) {
                    verseMap['$ch:$v'] = txt;
                  }
                }
              }
              if (verseMap.isNotEmpty) {
                await targetFile.writeAsString(jsonEncode(verseMap),
                    flush: true);
                _jsonCache[sourceId] = verseMap;
                onProgress?.call(1.0);
                return true;
              }
            }
          } catch (_) {
            continue;
          }
        }
        return false;
      }

      // Download .db.gz and decompress to .db
      final tempGzFile = File('${targetFile.path}.gz.tmp');
      bool downloaded = false;

      for (final url in info.downloadUrls) {
        try {
          final response = await _dio.download(
            url,
            tempGzFile.path,
            onReceiveProgress: (received, total) {
              if (onProgress != null) {
                final denom =
                    total > 0 ? total : (info.approxMb * 1024 * 1024).toInt();
                onProgress(((received / denom) * 0.85).clamp(0.0, 0.85));
              }
            },
          );
          if (response.statusCode == 200 &&
              await tempGzFile.exists() &&
              await tempGzFile.length() > 10240) {
            downloaded = true;
            break;
          }
        } catch (e) {
          debugPrint('[TafseerService] URL failed ($url): $e');
          continue;
        }
      }

      if (!downloaded) {
        if (await tempGzFile.exists()) await tempGzFile.delete();
        return false;
      }

      onProgress?.call(0.90);
      final compressedBytes = await tempGzFile.readAsBytes();
      final decompressedBytes =
          await compute(_decompressGzipBytes, compressedBytes);

      if (await tempGzFile.exists()) {
        await tempGzFile.delete();
      }

      if (_openDbs.containsKey(sourceId)) {
        _openDbs[sourceId]?.dispose();
        _openDbs.remove(sourceId);
      }

      await targetFile.writeAsBytes(decompressedBytes, flush: true);
      onProgress?.call(1.0);
      return true;
    } catch (e) {
      debugPrint('[TafseerService] Download failed for $sourceId: $e');
      return false;
    } finally {
      _downloadingIds.remove(sourceId);
    }
  }

  static List<int> _decompressGzipBytes(List<int> compressed) {
    return GZipDecoder().decodeBytes(compressed);
  }

  Future<void> deleteSource(String sourceId) async {
    if (_openDbs.containsKey(sourceId)) {
      _openDbs[sourceId]?.dispose();
      _openDbs.remove(sourceId);
    }
    _jsonCache.remove(sourceId);
    final file = await _getTargetFile(sourceId);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<sql.Database?> _getOpenDatabase(String sourceId) async {
    if (_openDbs.containsKey(sourceId)) {
      return _openDbs[sourceId];
    }
    final file = await _getTargetFile(sourceId);
    if (!await file.exists() || await file.length() <= 10240) {
      return null;
    }
    final db = sql.sqlite3.open(file.path, mode: sql.OpenMode.readOnly);
    _openDbs[sourceId] = db;
    return db;
  }

  Future<TafseerEntryResult?> getTafseerEntry(
    int surahId,
    int verseId,
    String surahName, {
    String? sourceId,
  }) async {
    final targetId = sourceId ?? availableSources.first.id;
    final info = getSourceInfo(targetId);

    try {
      if (info.isJsonEdition) {
        if (!_jsonCache.containsKey(targetId)) {
          final file = await _getTargetFile(targetId);
          if (!await file.exists()) return null;
          final raw = await file.readAsString();
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          _jsonCache[targetId] =
              decoded.map((k, v) => MapEntry(k, v.toString()));
        }
        final text = _jsonCache[targetId]?['$surahId:$verseId'];
        if (text == null || text.isEmpty) return null;
        return TafseerEntryResult(
          source: info,
          surahId: surahId,
          startVerse: verseId,
          endVerse: verseId,
          title: '$surahName Sûresi $verseId. Âyet',
          mealText: '',
          tefsirText: text,
        );
      }

      final db = await _getOpenDatabase(targetId);
      if (db == null) return null;

      // Fast O(1) indexed query on tafseer_entries(surah_id, start_verse, end_verse)
      final rows = db.select(
        '''
        SELECT title, meal_text, tefsir_text, start_verse, end_verse
        FROM tafseer_entries
        WHERE surah_id = ? AND start_verse <= ? AND end_verse >= ?
        ORDER BY (end_verse - start_verse) ASC, id ASC
        LIMIT 1
        ''',
        [surahId, verseId, verseId],
      );

      if (rows.isNotEmpty) {
        final row = rows.first;
        final startV = (row['start_verse'] as int?) ?? verseId;
        final endV = (row['end_verse'] as int?) ?? verseId;
        return TafseerEntryResult(
          source: info,
          surahId: surahId,
          startVerse: startV,
          endVerse: endV,
          title: (row['title'] as String?) ?? '$surahName Sûresi $verseId. Âyet',
          mealText: (row['meal_text'] as String?) ?? '',
          tefsirText: (row['tefsir_text'] as String?) ?? '',
        );
      }

      // Nearest preceding verse group fallback within the same surah
      final nearRows = db.select(
        '''
        SELECT title, meal_text, tefsir_text, start_verse, end_verse
        FROM tafseer_entries
        WHERE surah_id = ? AND start_verse <= ?
        ORDER BY start_verse DESC
        LIMIT 1
        ''',
        [surahId, verseId],
      );

      if (nearRows.isNotEmpty) {
        final row = nearRows.first;
        final startV = (row['start_verse'] as int?) ?? verseId;
        final endV = (row['end_verse'] as int?) ?? verseId;
        return TafseerEntryResult(
          source: info,
          surahId: surahId,
          startVerse: startV,
          endVerse: endV,
          title: (row['title'] as String?) ?? '$surahName Sûresi $verseId. Âyet',
          mealText: (row['meal_text'] as String?) ?? '',
          tefsirText: (row['tefsir_text'] as String?) ?? '',
        );
      }
    } catch (e) {
      debugPrint('[TafseerService] Query error ($targetId): $e');
    }

    return null;
  }

  /// Sayfadaki tüm âyetler için tekrarsız (gruplanmış âyetleri tek blok halinde birleştirerek)
  /// gerçek tefsir kayıtlarını döndürür.
  Future<List<TafseerEntryResult>> getUniqueEntriesForVerses(
    List<({int surahId, int verseId, String surahName})> verses, {
    String? sourceId,
  }) async {
    final List<TafseerEntryResult> results = [];
    final Set<String> seenRanges = {};

    for (final v in verses) {
      final entry = await getTafseerEntry(
        v.surahId,
        v.verseId,
        v.surahName,
        sourceId: sourceId,
      );
      if (entry != null && entry.tefsirText.trim().isNotEmpty) {
        final rangeKey =
            '${entry.surahId}:${entry.startVerse}-${entry.endVerse}';
        if (seenRanges.add(rangeKey)) {
          results.add(entry);
        }
      }
    }
    return results;
  }

  /// Backward-compatible string helper
  Future<String?> getTafseer(
    int surahId,
    int verseId,
    String surahName, {
    String? sourceId,
  }) async {
    final entry = await getTafseerEntry(
      surahId,
      verseId,
      surahName,
      sourceId: sourceId,
    );
    return entry?.tefsirText;
  }
}

final tafseerServiceProvider = Provider<TafseerService>((ref) => TafseerService());

class ActiveTafseerSourceNotifier extends StateNotifier<String> {
  static const _prefKey = 'kuran_active_tafseer_source';

  ActiveTafseerSourceNotifier() : super('kuran_yolu') {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null && saved.isNotEmpty) {
      state = saved;
    }
  }

  Future<void> setSource(String sourceId) async {
    state = sourceId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, sourceId);
  }
}

final activeTafseerSourceProvider =
    StateNotifierProvider<ActiveTafseerSourceNotifier, String>(
  (ref) => ActiveTafseerSourceNotifier(),
);
