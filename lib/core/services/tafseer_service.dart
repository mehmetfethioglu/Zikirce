import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import 'package:flutter/foundation.dart';

class TafseerRecord {
  final int id;
  final String bookTitle;
  final int surahId;
  final int startVerse;
  final int endVerse;
  final String? arabicText;
  final String turkishText;
  final String tefsirText;

  TafseerRecord({
    required this.id,
    required this.bookTitle,
    required this.surahId,
    required this.startVerse,
    required this.endVerse,
    this.arabicText,
    required this.turkishText,
    required this.tefsirText,
  });
}

class TafseerService {
  static sql.Database? _db;

  static Future<void> initialize() async {
    if (_db != null) return;

    try {
      final docDir = await getApplicationDocumentsDirectory();
      final dbPath = p.join(docDir.path, 'TevilatulKuran.db');
      final dbFile = File(dbPath);

      if (!dbFile.existsSync()) {
        debugPrint('[TafseerService] Copying TevilatulKuran.db from assets...');
        final byteData = await rootBundle.load('assets/raw/TevilatulKuran.db');
        await dbFile.writeAsBytes(byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        ));
      }

      _db = sql.sqlite3.open(dbPath);
      debugPrint('[TafseerService] Tafseer database loaded.');
    } catch (e) {
      debugPrint('[TafseerService] Error initializing Tafseer database: $e');
    }
  }

  /// Retrieves tafseer explanation for a specific surah and verse
  static TafseerRecord? getTafseer(int surahId, int verseId, String surahName) {
    if (_db == null) return null;

    try {
      final stmt = _db!.prepare('''
        SELECT id, book_title, arabic_text, turkish_text 
        FROM book_contents 
        WHERE turkish_text LIKE ?;
      ''');
      final rows = stmt.select(['%$surahName%']);
      stmt.dispose();

      final regex = RegExp(
        '$surahName\\s+(\\d+)(?:-(\\d+))?\\.?\\s+Ayet',
        caseSensitive: false,
      );

      for (final row in rows) {
        final turkishText = row['turkish_text']?.toString() ?? '';
        final match = regex.firstMatch(turkishText);
        if (match != null) {
          final start = int.tryParse(match.group(1) ?? '') ?? 1;
          final end = int.tryParse(match.group(2) ?? '') ?? start;

          if (verseId >= start && verseId <= end) {
            String tefsirText = turkishText;
            final tefsirIndex = turkishText.indexOf('Tefsiri');
            if (tefsirIndex != -1) {
              tefsirText = turkishText.substring(tefsirIndex + 7).trim();
              if (tefsirText.startsWith(':') || tefsirText.startsWith('-')) {
                tefsirText = tefsirText.substring(1).trim();
              }
            }

            return TafseerRecord(
              id: row['id'] as int? ?? 0,
              bookTitle: row['book_title']?.toString() ?? 'Te’vîlâtü’l-Kur’ân',
              surahId: surahId,
              startVerse: start,
              endVerse: end,
              arabicText: row['arabic_text']?.toString(),
              turkishText: turkishText,
              tefsirText: tefsirText,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[TafseerService] getTafseer error: $e');
    }

    return null;
  }
}
