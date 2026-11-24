import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/datasources/database_helper.dart';
import '../errors/app_error.dart';

class BackupRestoreSummary {
  final int booksRestored;
  final int highlightsRestored;
  final int sessionsRestored;
  final String filePath;

  const BackupRestoreSummary({
    this.booksRestored = 0,
    this.highlightsRestored = 0,
    this.sessionsRestored = 0,
    this.filePath = '',
  });

  int get totalItems => booksRestored + highlightsRestored + sessionsRestored;
}

class BackupRestoreService {
  static const String speedReadingPrefsKey = 'tahrir_speed_reading_progress_v1';

  final DatabaseHelper? dbHelper;

  const BackupRestoreService({this.dbHelper});

  DatabaseHelper get _db => dbHelper ?? DatabaseHelper.instance;

  /// Tüm kitap üstverilerini, alt çizili notları, okuma oturumlarını, alışkanlık profilini
  /// ve hızlı okuma ilerlemesini tek bir JSON metni olarak üretir.
  Future<Result<String>> buildBackupJsonString() async {
    try {
      final db = await _db.database;
      final books = await db.query('books');
      final highlights = await db.query('highlights');
      final readingSessions = await db.query('reading_sessions');
      final habitProfiles = await db.query('habit_profiles');

      final prefs = await SharedPreferences.getInstance();
      final speedReadingRaw = prefs.getString(speedReadingPrefsKey);

      final payload = <String, dynamic>{
        'schema_version': 1,
        'app': 'Tahrir',
        'exported_at': DateTime.now().toIso8601String(),
        'books': books,
        'highlights': highlights,
        'reading_sessions': readingSessions,
        'habit_profiles': habitProfiles,
        'speed_reading_progress': speedReadingRaw,
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(payload);
      return Result.success(jsonString);
    } catch (e, st) {
      return Result.failure(
        StorageError('Yedek verisi oluşturulamadı: $e', cause: e, stackTrace: st),
      );
    }
  }

  /// Yedek JSON dosyasını oluşturur, cihazın belgeler klasörüne kaydeder
  /// ve isteğe bağlı olarak sistem paylaşım penceresini açar.
  Future<Result<String>> exportBackupJson({bool shareFile = true}) async {
    try {
      final jsonResult = await buildBackupJsonString();
      if (jsonResult.isFailure) {
        return Result.failure(jsonResult.errorOrNull!);
      }

      final jsonString = jsonResult.dataOrNull!;
      final docsDir = await getApplicationDocumentsDirectory();
      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final fileName = 'tahrir_yedek_$stamp.json';
      final backupFile = File(p.join(docsDir.path, fileName));
      await backupFile.writeAsString(jsonString, flush: true);

      if (shareFile) {
        try {
          await Share.shareXFiles(
            [XFile(backupFile.path)],
            subject: 'Tahrir Kütüphane ve Not Yedeği ($stamp)',
          );
        } catch (_) {
          // Masaüstü / test ortamlarında paylaşım desteklenmiyorsa dosya yolu yeterlidir
        }
      }

      return Result.success(backupFile.path);
    } catch (e, st) {
      return Result.failure(
        StorageError('Yedek dışa aktarılamadı: $e', cause: e, stackTrace: st),
      );
    }
  }

  static const int _maxBackupBytes = 25 * 1024 * 1024;
  static const int _maxSpeedReadingBytes = 512 * 1024;
  static const Set<String> _allowedFormats = {
    'pdf',
    'epub',
    'txt',
    'markdown',
  };

  /// Seçilen bir JSON yedek dosyasından veya verilen JSON metninden/dosya yolundan
  /// kitapları, notları, oturumları, alışkanlık profilini ve hızlı okuma verilerini geri yükler.
  Future<Result<BackupRestoreSummary>> importBackupJson([
    String? rawJsonOrFilePath,
  ]) async {
    try {
      String? jsonContent;
      String sourcePath = '';

      if (rawJsonOrFilePath != null && rawJsonOrFilePath.trim().isNotEmpty) {
        final trimmed = rawJsonOrFilePath.trim();
        if (trimmed.startsWith('{')) {
          if (trimmed.length > _maxBackupBytes) {
            return const Result.failure(
              GeneralError('Yedek verisi izin verilen boyut sınırını (25 MB) aşıyor'),
            );
          }
          jsonContent = trimmed;
        } else {
          final file = File(trimmed);
          if (!await file.exists()) {
            return const Result.failure(
              GeneralError('Yedek dosyası bulunamadı'),
            );
          }
          final fileLen = await file.length();
          if (fileLen <= 0 || fileLen > _maxBackupBytes) {
            return const Result.failure(
              GeneralError('Yedek dosyası boyutu geçersiz veya 25 MB sınırını aşıyor'),
            );
          }
          sourcePath = file.path;
          jsonContent = await file.readAsString();
        }
      } else {
        final picked = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
        if (picked == null || picked.files.isEmpty) {
          return const Result.success(BackupRestoreSummary());
        }
        final pickedPath = picked.files.first.path;
        if (pickedPath == null || pickedPath.trim().isEmpty) {
          return const Result.failure(
            GeneralError('Seçilen yedek dosyası okunamadı'),
          );
        }
        final pickedFile = File(pickedPath);
        final pickedLen = await pickedFile.length();
        if (pickedLen <= 0 || pickedLen > _maxBackupBytes) {
          return const Result.failure(
            GeneralError('Seçilen yedek dosyası 25 MB sınırını aşıyor'),
          );
        }
        sourcePath = pickedPath;
        jsonContent = await pickedFile.readAsString();
      }

      if (jsonContent.length > _maxBackupBytes) {
        return const Result.failure(
          GeneralError('Yedek içeriği 25 MB sınırını aşıyor'),
        );
      }

      final decoded = jsonDecode(jsonContent);
      if (decoded is! Map<String, dynamic>) {
        return const Result.failure(
          ParsingError('Geçersiz Tahrir yedek dosyası formatı'),
        );
      }

      String? safeBooksDirPath;
      try {
        final docsDir = await getApplicationDocumentsDirectory();
        safeBooksDirPath = p.normalize(p.join(docsDir.path, 'tahrir_books'));
      } catch (_) {}

      final db = await _db.database;
      int restoredBooks = 0;
      int restoredHighlights = 0;
      int restoredSessions = 0;
      final nowIso = DateTime.now().toIso8601String();

      await db.transaction((txn) async {
        final existingBooks = await txn.query('books');
        final bookIdMap = <int, int>{};

        final booksList = decoded['books'];
        if (booksList is List) {
          for (final item in booksList.take(2000)) {
            if (item is! Map) continue;
            final map = Map<String, dynamic>.from(item);
            final oldId = (map['id'] as num?)?.toInt();
            final rawFilePath = (map['file_path'] ?? '').toString().trim();
            final title = (map['title'] ?? '').toString().trim();
            final author = (map['author'] ?? 'Bilinmeyen Yazar').toString().trim();
            if (title.isEmpty || rawFilePath.isEmpty || rawFilePath.contains('..')) {
              continue;
            }

            final isSamplePath = rawFilePath.startsWith('sample://');
            final isAllowedLocalPath = !isSamplePath &&
                safeBooksDirPath != null &&
                p.isWithin(safeBooksDirPath, p.normalize(rawFilePath));
            if (!isSamplePath && !isAllowedLocalPath) {
              continue;
            }

            final rawFormat = (map['format'] ?? 'pdf').toString().toLowerCase();
            final safeFormat =
                _allowedFormats.contains(rawFormat) ? rawFormat : 'pdf';
            final safeTotalPages =
                ((map['total_pages'] as num?)?.toInt() ?? 1).clamp(1, 50000);
            final safeCurrentPage =
                ((map['current_page'] as num?)?.toInt() ?? 1)
                    .clamp(1, safeTotalPages);
            final safeProgress =
                ((map['progress_percentage'] as num?)?.toDouble() ?? 0.0)
                    .clamp(0.0, 1.0);
            final safeReadingTime =
                ((map['total_reading_time_seconds'] as num?)?.toInt() ?? 0)
                    .clamp(0, 100000000);
            final safeEstimatedRem =
                ((map['estimated_remaining_minutes'] as num?)?.toInt() ?? 0)
                    .clamp(0, 1000000);
            final safeIsCompleted =
                ((map['is_completed'] as num?)?.toInt() ?? 0).clamp(0, 1);

            Map<String, Object?>? matchedExisting;
            for (final eb in existingBooks) {
              if (eb['file_path'] == rawFilePath ||
                  (eb['title'] == title && eb['author'] == author)) {
                matchedExisting = eb;
                break;
              }
            }

            if (matchedExisting != null) {
              final existingId = matchedExisting['id'] as int;
              if (oldId != null) {
                bookIdMap[oldId] = existingId;
              }
              await txn.update(
                'books',
                {
                  'current_page': safeCurrentPage,
                  'progress_percentage': safeProgress,
                  'total_reading_time_seconds': safeReadingTime,
                  'is_completed': safeIsCompleted,
                  'completed_date':
                      map['completed_date']?.toString() ?? matchedExisting['completed_date'],
                  'last_read_date':
                      map['last_read_date']?.toString() ?? matchedExisting['last_read_date'],
                },
                where: 'id = ?',
                whereArgs: [existingId],
              );
              restoredBooks++;
            } else {
              final safeInsertBook = <String, Object?>{
                'title': title.length > 300 ? title.substring(0, 300) : title,
                'author': author.length > 200 ? author.substring(0, 200) : author,
                'file_path': rawFilePath,
                'cover_image_path': null,
                'format': safeFormat,
                'total_pages': safeTotalPages,
                'current_page': safeCurrentPage,
                'progress_percentage': safeProgress,
                'total_reading_time_seconds': safeReadingTime,
                'estimated_remaining_minutes': safeEstimatedRem,
                'added_date': map['added_date']?.toString() ?? nowIso,
                'last_read_date': map['last_read_date']?.toString() ?? nowIso,
                'is_completed': safeIsCompleted,
                'completed_date': map['completed_date']?.toString(),
              };
              final newId = await txn.insert('books', safeInsertBook);
              if (oldId != null) {
                bookIdMap[oldId] = newId;
              }
              restoredBooks++;
            }
          }
        }

        final existingHighlights = await txn.query('highlights');
        final highlightsList = decoded['highlights'];
        if (highlightsList is List) {
          for (final item in highlightsList.take(5000)) {
            if (item is! Map) continue;
            final map = Map<String, dynamic>.from(item);
            final rawBookId = ((map['book_id'] as num?)?.toInt() ?? 1).clamp(1, 1000000);
            final targetBookId = bookIdMap[rawBookId] ?? rawBookId;
            final pageNum = ((map['page_number'] as num?)?.toInt() ?? 1).clamp(1, 50000);
            final selectedText = (map['selected_text'] ?? '').toString().trim();
            if (selectedText.isEmpty) continue;

            final alreadyExists = existingHighlights.any(
              (eh) =>
                  eh['book_id'] == targetBookId &&
                  eh['page_number'] == pageNum &&
                  eh['selected_text'] == selectedText,
            );
            if (!alreadyExists) {
              await txn.insert('highlights', {
                'book_id': targetBookId,
                'page_number': pageNum,
                'selected_text': selectedText.length > 5000
                    ? selectedText.substring(0, 5000)
                    : selectedText,
                'user_note': map['user_note']?.toString(),
                'category': (map['category'] ?? 'thought').toString(),
                'color_hex': (map['color_hex'] ?? '#FFE58F').toString(),
                'created_at': map['created_at']?.toString() ?? nowIso,
              });
              restoredHighlights++;
            }
          }
        }

        final existingSessions = await txn.query('reading_sessions');
        final sessionsList = decoded['reading_sessions'];
        if (sessionsList is List) {
          for (final item in sessionsList.take(5000)) {
            if (item is! Map) continue;
            final map = Map<String, dynamic>.from(item);
            final rawBookId = ((map['book_id'] as num?)?.toInt() ?? 1).clamp(1, 1000000);
            final targetBookId = bookIdMap[rawBookId] ?? rawBookId;
            final sessionDate = (map['session_date'] ?? '').toString().trim();
            final durationSeconds =
                ((map['duration_seconds'] as num?)?.toInt() ?? 0).clamp(0, 86400);
            final pagesRead =
                ((map['pages_read'] as num?)?.toInt() ?? 1).clamp(0, 5000);
            final wordsRead =
                ((map['words_read'] as num?)?.toInt() ?? 200).clamp(0, 500000);
            final calcWpm =
                ((map['calculated_wpm'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 2000.0);
            if (sessionDate.isEmpty) continue;

            final alreadyExists = existingSessions.any(
              (es) =>
                  es['session_date'] == sessionDate &&
                  es['duration_seconds'] == durationSeconds,
            );
            if (!alreadyExists) {
              await txn.insert('reading_sessions', {
                'book_id': targetBookId,
                'session_date': sessionDate,
                'duration_seconds': durationSeconds,
                'pages_read': pagesRead,
                'words_read': wordsRead,
                'calculated_wpm': calcWpm,
              });
              restoredSessions++;
            }
          }
        }

        final habitList = decoded['habit_profiles'];
        if (habitList is List && habitList.isNotEmpty && habitList.first is Map) {
          final importedHabit = Map<String, dynamic>.from(habitList.first as Map);
          final impStreak =
              ((importedHabit['current_streak'] as num?)?.toInt() ?? 0).clamp(0, 36500);
          final impLongest =
              ((importedHabit['longest_streak'] as num?)?.toInt() ?? 0).clamp(0, 36500);
          final impGoal =
              ((importedHabit['daily_goal_minutes'] as num?)?.toInt() ?? 20).clamp(5, 360);
          final impActiveDate =
              importedHabit['last_active_date']?.toString() ?? nowIso;

          final currentHabits = await txn.query('habit_profiles', limit: 1);
          if (currentHabits.isNotEmpty) {
            final current = currentHabits.first;
            final curStreak = ((current['current_streak'] as num?)?.toInt() ?? 0).clamp(0, 36500);
            final curLongest = ((current['longest_streak'] as num?)?.toInt() ?? 0).clamp(0, 36500);

            final mergedSeals = <String>{
              ...((current['earned_seals'] ?? '')
                  .toString()
                  .split(',')
                  .where((s) => s.trim().isNotEmpty)
                  .take(200)),
              ...((importedHabit['earned_seals'] ?? '')
                  .toString()
                  .split(',')
                  .where((s) => s.trim().isNotEmpty)
                  .take(200)),
            };

            await txn.update(
              'habit_profiles',
              {
                'last_active_date': impActiveDate,
                'current_streak': impStreak > curStreak ? impStreak : curStreak,
                'longest_streak': impLongest > curLongest ? impLongest : curLongest,
                'daily_goal_minutes': impGoal,
                'earned_seals': mergedSeals.join(','),
              },
              where: 'id = ?',
              whereArgs: [current['id']],
            );
          } else {
            await txn.insert('habit_profiles', {
              'last_active_date': impActiveDate,
              'current_streak': impStreak,
              'longest_streak': impLongest,
              'daily_goal_minutes': impGoal,
              'earned_seals': (importedHabit['earned_seals'] ?? '').toString(),
            });
          }
        }
      });

      final speedReadingRaw = decoded['speed_reading_progress'];
      if (speedReadingRaw is String &&
          speedReadingRaw.trim().isNotEmpty &&
          speedReadingRaw.length <= _maxSpeedReadingBytes) {
        try {
          final parsedSr = jsonDecode(speedReadingRaw);
          if (parsedSr is Map<String, dynamic>) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(speedReadingPrefsKey, speedReadingRaw);
          }
        } catch (_) {}
      }

      return Result.success(
        BackupRestoreSummary(
          booksRestored: restoredBooks,
          highlightsRestored: restoredHighlights,
          sessionsRestored: restoredSessions,
          filePath: sourcePath,
        ),
      );
    } catch (e, st) {
      return Result.failure(
        StorageError('Yedek geri yüklenemedi: $e', cause: e, stackTrace: st),
      );
    }
  }
}

final backupRestoreServiceProvider = Provider<BackupRestoreService>((ref) {
  return const BackupRestoreService();
});
