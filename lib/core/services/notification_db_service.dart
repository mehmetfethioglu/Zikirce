import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import 'package:flutter/foundation.dart';

class BildirimItem {
  final int id;
  final String title;
  final String content;
  final String category;

  BildirimItem({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
  });
}

class NotificationDbService {
  static sql.Database? _db;

  static Future<void> initialize() async {
    if (_db != null) return;

    try {
      final docDir = await getApplicationDocumentsDirectory();
      final dbPath = p.join(docDir.path, 'bildirim.db');
      final dbFile = File(dbPath);

      if (!dbFile.existsSync()) {
        debugPrint('[NotificationDbService] Copying bildirim.db from assets...');
        final byteData = await rootBundle.load('assets/raw/bildirim.db');
        await dbFile.writeAsBytes(byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        ));
      }

      _db = sql.sqlite3.open(dbPath);
      debugPrint('[NotificationDbService] bildirim.db loaded.');
    } catch (e) {
      debugPrint('[NotificationDbService] Error initializing bildirim database: $e');
    }
  }

  /// Fetches a random daily Islamic quote, hadith, or reminder
  static BildirimItem? getRandomNotification() {
    if (_db == null) return null;

    try {
      final rows = _db!.select('SELECT rowid as fallback_id, * FROM bildirimler ORDER BY RANDOM() LIMIT 1;');
      if (rows.isNotEmpty) {
        final r = rows.first;
        final idVal = r['id'] ?? r['Id'] ?? r['ID'] ?? r['fallback_id'] ?? 1;
        return BildirimItem(
          id: idVal is int ? idVal : (int.tryParse(idVal.toString()) ?? 1),
          title: (r['baslik'] ?? r['Baslik'] ?? r['title'] ?? 'Günün Hatırlatması').toString(),
          content: (r['metin'] ?? r['Metin'] ?? r['content'] ?? 'Rabbinin adını zikret ve bütün varlığınla O’na yönel.').toString(),
          category: (r['kategori'] ?? r['Kategori'] ?? r['category'] ?? 'Zikir').toString(),
        );
      }
    } catch (e) {
      debugPrint('[NotificationDbService] Query error: $e');
    }

    return BildirimItem(
      id: 1,
      title: 'Günün Zikri',
      content: 'Kalpler ancak Allah’ı anmakla huzur bulur. (Rad, 28)',
      category: 'Zikir',
    );
  }
}
