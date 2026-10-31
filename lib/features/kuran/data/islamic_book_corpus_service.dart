import 'dart:io';
import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import '../../../core/constants/surah_data_provider.dart';

/// Tek bir kitap sayfasının (Hadis veya Risale-i Nur) tam metin verisi
class IslamicBookPageData {
  final int pageNo;
  final int chapterId;
  final String chapterTitle;
  final String subtitle;
  final String arabicText;
  final String turkishText;
  final String explanation;
  final String reference;

  const IslamicBookPageData({
    required this.pageNo,
    required this.chapterId,
    required this.chapterTitle,
    required this.subtitle,
    required this.arabicText,
    required this.turkishText,
    required this.explanation,
    required this.reference,
  });
}

/// Kitap içindekiler (Bölüm / Bab / Risale) başlığı
class IslamicBookChapterData {
  final int chapterId;
  final String title;
  final int startPage;
  final int pageCount;

  const IslamicBookChapterData({
    required this.chapterId,
    required this.title,
    required this.startPage,
    required this.pageCount,
  });
}

/// Tefsir kitaplarında her âyeti 1 sayfa (1..6236) olarak göstermek için
/// 6.236 âyetlik global sayfa <-> (surahId, ayahId, surahName, mushafPage) eşleyicisi.
class QuranGlobalAyahLocation {
  final int globalPage; // 1..6236
  final int surahId; // 1..114
  final int ayahId; // 1..N
  final String surahName;
  final String surahArabicName;
  final int mushafStartPage;
  final int surahTotalAyahs;

  const QuranGlobalAyahLocation({
    required this.globalPage,
    required this.surahId,
    required this.ayahId,
    required this.surahName,
    required this.surahArabicName,
    required this.mushafStartPage,
    required this.surahTotalAyahs,
  });
}

class QuranAyahPageMapper {
  static const int totalQuranAyahs = 6236;

  static List<int>? _surahStartGlobalOffsets;

  static void _ensureInitialized() {
    if (_surahStartGlobalOffsets != null) return;
    final offsets = <int>[0]; // 1-based indexing helper
    int running = 1;
    for (final s in SurahDataProvider.surahs) {
      offsets.add(running);
      running += s.ayetSayisi;
    }
    _surahStartGlobalOffsets = offsets;
  }

  /// Global âyet sayfasından (1..6236) sûre ve âyet bilgisini döndürür
  static QuranGlobalAyahLocation fromGlobalPage(int globalPage) {
    _ensureInitialized();
    final clamped = globalPage.clamp(1, totalQuranAyahs);
    final offsets = _surahStartGlobalOffsets!;
    const surahs = SurahDataProvider.surahs;

    int chosenSurahIdx = 0;
    for (int i = 0; i < surahs.length; i++) {
      final start = offsets[i + 1];
      final end = start + surahs[i].ayetSayisi - 1;
      if (clamped >= start && clamped <= end) {
        chosenSurahIdx = i;
        break;
      }
    }

    final surah = surahs[chosenSurahIdx];
    final startOffset = offsets[chosenSurahIdx + 1];
    final ayahId = (clamped - startOffset + 1).clamp(1, surah.ayetSayisi);

    return QuranGlobalAyahLocation(
      globalPage: clamped,
      surahId: surah.id,
      ayahId: ayahId,
      surahName: surah.name,
      surahArabicName: surah.nameArabic,
      mushafStartPage: surah.startPage,
      surahTotalAyahs: surah.ayetSayisi,
    );
  }

  /// Sûre (1..114) ve Âyet (1..N) numarasından global sayfa numarasını (1..6236) döndürür
  static int toGlobalPage(int surahId, int ayahId) {
    _ensureInitialized();
    final offsets = _surahStartGlobalOffsets!;
    const surahs = SurahDataProvider.surahs;
    final idx = (surahId - 1).clamp(0, surahs.length - 1);
    final surah = surahs[idx];
    final clampedAyah = ayahId.clamp(1, surah.ayetSayisi);
    return (offsets[idx + 1] + clampedAyah - 1).clamp(1, totalQuranAyahs);
  }
}

/// Kütüb-i Sitte, Riyâzü's-Sâlihîn ve Risale-i Nur Külliyatı tam metin SQLite servisi
class IslamicBookCorpusService {
  static final IslamicBookCorpusService _instance =
      IslamicBookCorpusService._internal();
  factory IslamicBookCorpusService() => _instance;
  IslamicBookCorpusService._internal();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 25),
      receiveTimeout: const Duration(seconds: 120),
      headers: const {'Accept': '*/*', 'User-Agent': 'Zikirce-App/2.1'},
    ),
  );

  final Map<String, sql.Database> _openDbs = {};
  String? _booksDirPath;

  static const Map<String, String> _approxSizeLabels = {
    'buhari': '4.9 MB',
    'muslim': '3.3 MB',
    'tirmizi': '1.8 MB',
    'ebu_davud': '2.1 MB',
    'nesai': '0.2 MB',
    'ibn_mace': '1.9 MB',
    'riyazus_salihin': '0.5 MB',
    'rn_sozler': '0.7 MB',
    'rn_mektubat': '0.5 MB',
    'rn_lemalar': '0.4 MB',
    'rn_sualar': '0.5 MB',
    'rn_mesnevi': '0.2 MB',
    'rn_isaratul_icaz': '0.2 MB',
    'rn_asayi_musa': '0.2 MB',
    'rn_kucuk_sozler': '0.1 MB',
    'rn_meyve_risalesi': '0.1 MB',
    'rn_hastalar_risalesi': '0.1 MB',
    'rn_genclik_rehberi': '0.1 MB',
    'rn_hanimlar_rehberi': '0.1 MB',
    'rn_ihlas_uhuvvet': '0.1 MB',
    'rn_ramazan_iktisat_sukur': '0.1 MB',
    'rn_hasir_risalesi': '0.1 MB',
    'rn_tabiat_risalesi': '0.1 MB',
    'rn_ihtiyarlar_risalesi': '0.1 MB',
    'rn_ayetul_kubra': '0.1 MB',
    'rn_munacat_risalesi': '0.1 MB',
    'rn_mirac_kader': '0.1 MB',
    'rn_hutbe_munazarat': '0.2 MB',
    'rn_nurun_ilk_kapisi': '0.1 MB',
    'rn_muhakemat': '0.1 MB',
    'rn_lugat': '3.0 MB',
  };

  String getApproxSizeLabel(String sourceKey) =>
      _approxSizeLabels[sourceKey] ?? '0.2 MB';

  List<String> _downloadUrlsFor(String sourceKey) {
    final fileName = '${sourceKey}_v1.db.gz';
    return [
      'https://raw.githubusercontent.com/mehmetfethioglu/zikirce-indir/eaab030/books/$fileName',
      'https://raw.githubusercontent.com/mehmetfethioglu/zikirce-indir/main/books/$fileName?v=3',
      'https://mehmetfethioglu.github.io/zikirce-indir/books/$fileName?v=3',
    ];
  }

  Future<String> _getBooksDir() async {
    if (_booksDirPath != null) return _booksDirPath!;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'kulliyat_books_v1'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _booksDirPath = dir.path;
    return _booksDirPath!;
  }

  Future<String> _dbFilePath(String sourceKey) async {
    final dir = await _getBooksDir();
    return p.join(dir, '${sourceKey}_v1.db');
  }

  Future<bool> isBookDownloaded(String sourceKey) async {
    final path = await _dbFilePath(sourceKey);
    final file = File(path);
    if (!await file.exists()) return false;
    final len = await file.length();
    if (len <= 16384) return false;
    final db = await _getDb(sourceKey);
    return db != null;
  }

  Future<bool> downloadBook(
    String sourceKey, {
    void Function(double progress)? onProgress,
  }) async {
    final targetPath = await _dbFilePath(sourceKey);
    final tempGzPath = '$targetPath.gz.tmp';

    for (final url in _downloadUrlsFor(sourceKey)) {
      try {
        await _dio.download(
          url,
          tempGzPath,
          onReceiveProgress: (received, total) {
            if (total > 0 && onProgress != null) {
              onProgress((received / total).clamp(0.0, 0.95));
            }
          },
        );

        final gzFile = File(tempGzPath);
        if (!await gzFile.exists() || await gzFile.length() < 512) {
          continue;
        }

        final compressedBytes = await gzFile.readAsBytes();
        final decompressedBytes = await compute(_decompressGzip, compressedBytes);

        final outFile = File(targetPath);
        await outFile.writeAsBytes(decompressedBytes, flush: true);
        try {
          await gzFile.delete();
        } catch (_) {}

        onProgress?.call(1.0);
        return true;
      } catch (e) {
        debugPrint('IslamicBookCorpusService download error ($url): $e');
      }
    }
    return false;
  }

  static List<int> _decompressGzip(List<int> bytes) {
    return GZipDecoder().decodeBytes(bytes);
  }

  Future<sql.Database?> _getDb(String sourceKey) async {
    if (_openDbs.containsKey(sourceKey)) {
      return _openDbs[sourceKey];
    }
    final dbPath = await _dbFilePath(sourceKey);
    final file = File(dbPath);
    if (!await file.exists() || await file.length() < 16384) {
      return null;
    }
    try {
      final db = sql.sqlite3.open(dbPath, mode: sql.OpenMode.readOnly);
      final tbl = db.select(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='pages' LIMIT 1",
      );
      if (tbl.isEmpty) {
        db.dispose();
        try {
          await file.delete();
        } catch (_) {}
        return null;
      }
      _openDbs[sourceKey] = db;
      return db;
    } catch (e) {
      debugPrint('IslamicBookCorpusService open error ($sourceKey): $e');
      return null;
    }
  }

  Future<int?> getTotalPages(String sourceKey) async {
    final db = await _getDb(sourceKey);
    if (db == null) return null;
    try {
      final res = db.select('SELECT COUNT(*) AS cnt FROM pages');
      if (res.isNotEmpty) {
        return (res.first['cnt'] as num?)?.toInt();
      }
    } catch (_) {}
    return null;
  }

  Future<IslamicBookPageData?> getPage(String sourceKey, int pageNo) async {
    final db = await _getDb(sourceKey);
    if (db == null) return null;
    try {
      final res = db.select(
        'SELECT page_no, chapter_id, chapter_title, subtitle, arabic_text, turkish_text, explanation, reference FROM pages WHERE page_no = ? LIMIT 1',
        [pageNo],
      );
      if (res.isEmpty) return null;
      final row = res.first;
      return IslamicBookPageData(
        pageNo: (row['page_no'] as num?)?.toInt() ?? pageNo,
        chapterId: (row['chapter_id'] as num?)?.toInt() ?? 1,
        chapterTitle: (row['chapter_title'] as String?) ?? '',
        subtitle: (row['subtitle'] as String?) ?? '',
        arabicText: (row['arabic_text'] as String?) ?? '',
        turkishText: (row['turkish_text'] as String?) ?? '',
        explanation: (row['explanation'] as String?) ?? '',
        reference: (row['reference'] as String?) ?? '',
      );
    } catch (e) {
      debugPrint('IslamicBookCorpusService getPage error: $e');
      return null;
    }
  }

  Future<List<IslamicBookChapterData>> getChapters(String sourceKey) async {
    final db = await _getDb(sourceKey);
    if (db == null) return const [];
    try {
      final res = db.select(
        'SELECT chapter_id, title, start_page, page_count FROM chapters ORDER BY chapter_id ASC',
      );
      return res
          .map(
            (r) => IslamicBookChapterData(
              chapterId: (r['chapter_id'] as num?)?.toInt() ?? 1,
              title: (r['title'] as String?) ?? '',
              startPage: (r['start_page'] as num?)?.toInt() ?? 1,
              pageCount: (r['page_count'] as num?)?.toInt() ?? 1,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('IslamicBookCorpusService getChapters error: $e');
      return const [];
    }
  }

  Future<List<IslamicBookPageData>> searchBook(
    String sourceKey,
    String query, {
    int limit = 40,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];
    final db = await _getDb(sourceKey);
    if (db == null) return const [];
    try {
      final pattern = '%$trimmed%';
      final res = db.select(
        'SELECT page_no, chapter_id, chapter_title, subtitle, arabic_text, turkish_text, explanation, reference FROM pages WHERE turkish_text LIKE ? OR chapter_title LIKE ? OR subtitle LIKE ? ORDER BY page_no ASC LIMIT ?',
        [pattern, pattern, pattern, limit],
      );
      return res
          .map(
            (row) => IslamicBookPageData(
              pageNo: (row['page_no'] as num?)?.toInt() ?? 1,
              chapterId: (row['chapter_id'] as num?)?.toInt() ?? 1,
              chapterTitle: (row['chapter_title'] as String?) ?? '',
              subtitle: (row['subtitle'] as String?) ?? '',
              arabicText: (row['arabic_text'] as String?) ?? '',
              turkishText: (row['turkish_text'] as String?) ?? '',
              explanation: (row['explanation'] as String?) ?? '',
              reference: (row['reference'] as String?) ?? '',
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }
}

final islamicBookCorpusServiceProvider =
    Provider<IslamicBookCorpusService>((ref) {
  return IslamicBookCorpusService();
});
