import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'audio_sync_service.dart';
import 'local_notification_service.dart';

class AudioDownloadProgress {
  final int completed;
  final int total;
  final double progress; // 0.0 to 1.0
  final String statusText;
  final bool isDownloading;
  final bool isPaused;
  final String? currentItem;

  const AudioDownloadProgress({
    this.completed = 0,
    this.total = 0,
    this.progress = 0.0,
    this.statusText = '',
    this.isDownloading = false,
    this.isPaused = false,
    this.currentItem,
  });

  AudioDownloadProgress copyWith({
    int? completed,
    int? total,
    double? progress,
    String? statusText,
    bool? isDownloading,
    bool? isPaused,
    String? currentItem,
  }) {
    return AudioDownloadProgress(
      completed: completed ?? this.completed,
      total: total ?? this.total,
      progress: progress ?? this.progress,
      statusText: statusText ?? this.statusText,
      isDownloading: isDownloading ?? this.isDownloading,
      isPaused: isPaused ?? this.isPaused,
      currentItem: currentItem ?? this.currentItem,
    );
  }
}

class AudioDownloadService {
  static final AudioDownloadService _instance = AudioDownloadService._internal();
  factory AudioDownloadService() => _instance;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 25),
      sendTimeout: const Duration(seconds: 15),
      headers: {
        'User-Agent': 'Zikirce/2.0 (Android/iOS; QuranAudioDownloader)',
      },
    ),
  );

  bool _isCancelled = false;
  bool _isPaused = false;
  bool _isDownloading = false;

  /// Prevents concurrent downloads of the same verse from colliding on .tmp files
  static final Map<String, Future<bool>> _inFlightDownloads = {};

  final StreamController<AudioDownloadProgress> _progressController =
      StreamController<AudioDownloadProgress>.broadcast();

  Stream<AudioDownloadProgress> get progressStream => _progressController.stream;
  bool get isDownloading => _isDownloading;
  bool get isPaused => _isPaused;

  AudioDownloadService._internal();

  /// Returns the local Sounds directory
  static Future<Directory> getSoundsDirectory() async {
    final docDir = await getApplicationDocumentsDirectory();
    final soundsDir = Directory(p.join(docDir.path, 'Sounds'));
    if (!soundsDir.existsSync()) {
      soundsDir.createSync(recursive: true);
    }
    return soundsDir;
  }

  /// Returns the absolute path of a local audio file for surah and ayah
  static Future<String> getLocalAudioPath(int surahId, int ayahId) async {
    final soundsDir = await getSoundsDirectory();
    return p.join(soundsDir.path, 'audio_${surahId}_$ayahId.mp3');
  }

  /// Validates that a local MP3 file exists, is non-empty, and is an authentic
  /// Diyanet Hafız Osman Şahin recording (not a cached EveryAyah Alafasy or Mehmet Çevik file).
  static bool isValidDiyanetAudioFile(File file) {
    try {
      if (!file.existsSync()) return false;
      final len = file.lengthSync();
      if (len <= 500) return false;
      final raf = file.openSync(mode: FileMode.read);
      try {
        final header = raf.readSync(4);
        if (header.length >= 4) {
          final isEveryAyahCrc = header[0] == 0xFF && header[1] == 0xFA;
          final isWrongBitrate = header[0] == 0xFF &&
              header[1] == 0xFB &&
              (header[2] & 0xF0) != 0x50;
          final isMehmetCevikId3v23 = header[0] == 0x49 &&
              header[1] == 0x44 &&
              header[2] == 0x33 &&
              header[3] == 0x03;

          if (isEveryAyahCrc || isWrongBitrate || isMehmetCevikId3v23) {
            try {
              raf.closeSync();
              file.deleteSync();
            } catch (_) {}
            return false;
          }
        }
      } finally {
        try {
          raf.closeSync();
        } catch (_) {}
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Synchronously checks if audio file exists if sounds directory is known
  static bool isAudioFileDownloaded(String soundsDirPath, int surahId, int ayahId) {
    final filePath = p.join(soundsDirPath, 'audio_${surahId}_$ayahId.mp3');
    return isValidDiyanetAudioFile(File(filePath));
  }

  /// Checks if a verse audio is downloaded locally
  static Future<bool> isAudioDownloaded(int surahId, int ayahId) async {
    final path = await getLocalAudioPath(surahId, ayahId);
    return isValidDiyanetAudioFile(File(path));
  }

  /// Returns the primary Diyanet CDN URL for a verse (always ar_osmanSahin for 100% reciter & word-sync consistency)
  static String getDiyanetAudioUrl(int surahId, int ayahId, {int? pageId}) {
    const baseUrl = 'https://webdosya.diyanet.gov.tr/kuran/kuranikerim/Sound/ar_osmanSahin';
    return '$baseUrl/${surahId}_$ayahId.mp3';
  }

  /// Returns secondary Diyanet CDN URL (ar_mehmetCevik) if primary CDN node fails
  static String getDiyanetSecondaryAudioUrl(int surahId, int ayahId) {
    const baseUrl = 'https://webdosya.diyanet.gov.tr/kuran/kuranikerim/Sound/ar_mehmetCevik';
    return '$baseUrl/${surahId}_$ayahId.mp3';
  }

  /// Returns EveryAyah fallback URL if Diyanet CDN is completely unreachable for streaming
  static String getFallbackAudioUrl(int surahId, int ayahId) {
    final s = surahId.toString().padLeft(3, '0');
    final a = ayahId.toString().padLeft(3, '0');
    return 'https://everyayah.com/data/Alafasy_128kbps/$s$a.mp3';
  }

  /// Gets the count of all downloaded audio files
  static Future<int> getDownloadedAudioCount() async {
    try {
      final dir = await getSoundsDirectory();
      final files = dir.listSync().whereType<File>().where((f) {
        final name = p.basename(f.path);
        return name.startsWith('audio_') && name.endsWith('.mp3') && f.lengthSync() > 0;
      });
      return files.length;
    } catch (e) {
      debugPrint('[AudioDownloadService] getDownloadedAudioCount error: $e');
      return 0;
    }
  }

  /// Gets total storage size of downloaded audio files in megabytes (MB)
  static Future<double> getTotalStorageSizeMb() async {
    try {
      final dir = await getSoundsDirectory();
      int totalBytes = 0;
      final files = dir.listSync().whereType<File>().where((f) {
        final name = p.basename(f.path);
        return name.startsWith('audio_') && name.endsWith('.mp3');
      });
      for (final f in files) {
        totalBytes += f.lengthSync();
      }
      return (totalBytes / (1024 * 1024));
    } catch (e) {
      debugPrint('[AudioDownloadService] getTotalStorageSizeMb error: $e');
      return 0.0;
    }
  }

  /// Deletes all downloaded audio files and cleans up storage
  static Future<void> deleteAllAudios() async {
    try {
      final dir = await getSoundsDirectory();
      final files = dir.listSync().whereType<File>().where((f) {
        final name = p.basename(f.path);
        return (name.startsWith('audio_') && name.endsWith('.mp3')) ||
            name.endsWith('.tmp');
      });
      for (final f in files) {
        try {
          f.deleteSync();
        } catch (_) {}
      }
      await LocalNotificationService.cancelDownloadNotification();
    } catch (e) {
      debugPrint('[AudioDownloadService] deleteAllAudios error: $e');
    }
  }

  /// Deletes all audio files belonging to a specific Juz (1 to 30)
  static Future<void> deleteJuzAudios(int juzNumber) async {
    try {
      final verses = await AudioSyncService.getVersesByJuz(juzNumber);
      for (final v in verses) {
        final path = await getLocalAudioPath(v.surahId, v.ayahId);
        final file = File(path);
        if (file.existsSync()) {
          try {
            file.deleteSync();
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[AudioDownloadService] deleteJuzAudios error: $e');
    }
  }

  /// Returns (downloadedCount, totalCount) for a specific Juz (1 to 30)
  static Future<({int downloaded, int total})> getJuzDownloadStatus(int juzNumber) async {
    try {
      final dir = await getSoundsDirectory();
      final soundsDirPath = dir.path;
      final verses = await AudioSyncService.getVersesByJuz(juzNumber);
      if (verses.isEmpty) return (downloaded: 0, total: 0);

      int downloaded = 0;
      for (final v in verses) {
        if (isAudioFileDownloaded(soundsDirPath, v.surahId, v.ayahId)) {
          downloaded++;
        }
      }
      return (downloaded: downloaded, total: verses.length);
    } catch (e) {
      debugPrint('[AudioDownloadService] getJuzDownloadStatus error: $e');
      return (downloaded: 0, total: 0);
    }
  }

  /// Requests download cancellation
  void cancelDownload() {
    _isCancelled = true;
    _isPaused = false;
    _isDownloading = false;
    LocalNotificationService.cancelDownloadNotification();
    _progressController.add(const AudioDownloadProgress(
      isDownloading: false,
      statusText: 'İndirme iptal edildi.',
    ));
  }

  /// Toggles Pause / Resume
  void togglePause() {
    if (!_isDownloading) return;
    _isPaused = !_isPaused;
  }

  /// Downloads all 6,236 Quran verses
  Future<bool> downloadAllQuran({
    void Function(AudioDownloadProgress progress)? onProgress,
  }) async {
    final verses = await AudioSyncService.getAllDistinctVerses();
    if (verses.isEmpty) {
      debugPrint('[AudioDownloadService] No verses found in AudioSyncService database.');
      return false;
    }
    return downloadVerses(
      verses: verses,
      onProgress: onProgress,
      title: 'Tüm Kur\'an-ı Kerim',
    );
  }

  /// Downloads a specific Juz
  Future<bool> downloadJuz(
    int juzNumber, {
    void Function(AudioDownloadProgress progress)? onProgress,
  }) async {
    final verses = await AudioSyncService.getVersesByJuz(juzNumber);
    if (verses.isEmpty) return false;
    return downloadVerses(
      verses: verses,
      onProgress: onProgress,
      title: '$juzNumber. Cüz',
    );
  }

  /// Downloads a specific Quran Page (1 to 604)
  Future<bool> downloadPageAudios({
    required int pageNumber,
    void Function(AudioDownloadProgress progress)? onProgress,
  }) async {
    final verses = await AudioSyncService.getVersesByPage(pageNumber);
    if (verses.isEmpty) return false;
    return downloadVerses(
      verses: verses,
      onProgress: onProgress,
      title: 'Sayfa $pageNumber',
    );
  }

  /// Downloads a specific Surah (1 to 114)
  Future<bool> downloadSurahAudios({
    required int surahId,
    String? surahName,
    void Function(AudioDownloadProgress progress)? onProgress,
  }) async {
    final allVerses = await AudioSyncService.getAllDistinctVerses();
    final surahVerses = allVerses.where((v) => v.surahId == surahId).toList();
    if (surahVerses.isEmpty) return false;
    return downloadVerses(
      verses: surahVerses,
      onProgress: onProgress,
      title: surahName ?? '$surahId. Sûre',
    );
  }

  /// Multi-worker resilient downloader
  Future<bool> downloadVerses({
    required List<VerseAudioInfo> verses,
    void Function(AudioDownloadProgress progress)? onProgress,
    String title = 'Ses Dosyaları',
  }) async {
    if (_isDownloading) {
      debugPrint('[AudioDownloadService] Download already in progress.');
      return false;
    }

    _isDownloading = true;
    _isCancelled = false;
    _isPaused = false;

    final dir = await getSoundsDirectory();
    final soundsDirPath = dir.path;
    final total = verses.length;

    // Filter verses that are already downloaded
    final missingVerses = <VerseAudioInfo>[];
    int alreadyDownloaded = 0;

    for (final v in verses) {
      if (isAudioFileDownloaded(soundsDirPath, v.surahId, v.ayahId)) {
        alreadyDownloaded++;
      } else {
        missingVerses.add(v);
      }
    }

    int completed = alreadyDownloaded;
    double initialProgress = total > 0 ? (completed / total) : 1.0;

    var currentProgress = AudioDownloadProgress(
      completed: completed,
      total: total,
      progress: initialProgress,
      statusText: '%${(initialProgress * 100).toInt()} indiriliyor...',
      isDownloading: true,
      isPaused: false,
    );

    _progressController.add(currentProgress);
    onProgress?.call(currentProgress);
    await LocalNotificationService.showDownloadProgressNotification(
      current: completed,
      total: total,
      statusText: '%${(initialProgress * 100).toInt()} indiriliyor...',
    );

    if (missingVerses.isEmpty) {
      currentProgress = currentProgress.copyWith(
        completed: total,
        progress: 1.0,
        statusText: 'Tüm ses dosyaları zaten mevcut.',
        isDownloading: false,
      );
      _progressController.add(currentProgress);
      onProgress?.call(currentProgress);
      _isDownloading = false;
      await LocalNotificationService.showDownloadCompletedNotification(total: total);
      return true;
    }

    // Concurrency pool: 4 workers
    const int concurrency = 4;
    int index = 0;
    int activeWorkers = 0;
    final Completer<void> completer = Completer<void>();
    DateTime lastNotificationTime = DateTime.now();

    void checkAndDispatch() {
      if (_isCancelled) {
        if (activeWorkers == 0 && !completer.isCompleted) {
          completer.complete();
        }
        return;
      }

      if (index >= missingVerses.length) {
        if (activeWorkers == 0 && !completer.isCompleted) {
          completer.complete();
        }
        return;
      }

      while (activeWorkers < concurrency && index < missingVerses.length && !_isCancelled) {
        final currentVerse = missingVerses[index++];
        activeWorkers++;

        _downloadSingleVerseFile(currentVerse, soundsDirPath).then((success) async {
          activeWorkers--;
          if (success) {
            completed++;
          }
          final progVal = (completed / total).clamp(0.0, 1.0);

          currentProgress = currentProgress.copyWith(
            completed: completed,
            total: total,
            progress: progVal,
            statusText: '%${(progVal * 100).toInt()} ($completed/$total)',
            currentItem: '${currentVerse.surahId}. Sûre ${currentVerse.ayahId}. Âyet',
          );

          _progressController.add(currentProgress);
          onProgress?.call(currentProgress);

          // Throttle notification updates (every 1.5 seconds or upon completion)
          final now = DateTime.now();
          if (now.difference(lastNotificationTime).inMilliseconds > 1500 || completed == total) {
            lastNotificationTime = now;
            await LocalNotificationService.showDownloadProgressNotification(
              current: completed,
              total: total,
              statusText: '%${(progVal * 100).toInt()} ($completed / $total)',
            );
          }

          // Small 25ms yield to prevent event loop starvation
          await Future.delayed(const Duration(milliseconds: 25));
          checkAndDispatch();
        }).catchError((err) async {
          activeWorkers--;
          debugPrint('[AudioDownloadService] Error on ${currentVerse.surahId}:${currentVerse.ayahId}: $err');
          checkAndDispatch();
        });
      }
    }

    checkAndDispatch();
    await completer.future;

    _isDownloading = false;

    if (_isCancelled) {
      await LocalNotificationService.cancelDownloadNotification();
      return false;
    }

    final actualCount = await getDownloadedAudioCount();
    final isFullyCompleted = actualCount >= total;

    currentProgress = currentProgress.copyWith(
      completed: actualCount,
      total: total,
      progress: (actualCount / total).clamp(0.0, 1.0),
      statusText: isFullyCompleted
          ? 'Tüm ses dosyaları başarıyla indirildi ($actualCount/$total).'
          : '$actualCount / $total ses dosyası indirildi.',
      isDownloading: false,
    );
    _progressController.add(currentProgress);
    onProgress?.call(currentProgress);

    if (isFullyCompleted) {
      await LocalNotificationService.showDownloadCompletedNotification(total: total);
    } else {
      await LocalNotificationService.showDownloadProgressNotification(
        current: actualCount,
        total: total,
        statusText: '$actualCount / $total indirildi (Kalan: ${total - actualCount})',
      );
    }
    return isFullyCompleted;
  }

  /// Downloads a single verse file with atomic .tmp write and in-flight lock
  Future<bool> _downloadSingleVerseFile(VerseAudioInfo verse, String soundsDirPath) async {
    final key = '${verse.surahId}_${verse.ayahId}';
    final existingFuture = _inFlightDownloads[key];
    if (existingFuture != null) {
      return existingFuture;
    }

    final future = _performSingleVerseDownload(verse, soundsDirPath);
    _inFlightDownloads[key] = future;
    try {
      return await future;
    } finally {
      _inFlightDownloads.remove(key);
    }
  }

  Future<bool> _performSingleVerseDownload(VerseAudioInfo verse, String soundsDirPath) async {
    final finalPath = p.join(soundsDirPath, 'audio_${verse.surahId}_${verse.ayahId}.mp3');
    final tmpPath = '$finalPath.${DateTime.now().microsecondsSinceEpoch}.tmp';

    if (isValidDiyanetAudioFile(File(finalPath))) {
      return true;
    }

    final diyanetUrl = getDiyanetAudioUrl(verse.surahId, verse.ayahId, pageId: verse.pageId);

    // Strictly use Diyanet CDN (Hafız Osman Şahin) so audio 100% matches ZikirceAudioSync.db word timestamps
    bool downloaded = await _tryDownloadUrl(diyanetUrl, tmpPath, timeoutSec: 15);
    if (!downloaded) {
      await Future.delayed(const Duration(milliseconds: 250));
      downloaded = await _tryDownloadUrl(diyanetUrl, tmpPath, timeoutSec: 12);
    }
    if (!downloaded) {
      await Future.delayed(const Duration(milliseconds: 500));
      downloaded = await _tryDownloadUrl(diyanetUrl, tmpPath, timeoutSec: 15);
    }

    if (downloaded && File(tmpPath).existsSync() && File(tmpPath).lengthSync() > 500) {
      final tmpFile = File(tmpPath);
      if (File(finalPath).existsSync()) {
        try {
          File(finalPath).deleteSync();
        } catch (_) {}
      }
      try {
        tmpFile.renameSync(finalPath);
        return true;
      } catch (e) {
        debugPrint('[AudioDownloadService] Rename tmp failed: $e');
        try {
          tmpFile.deleteSync();
        } catch (_) {}
        return false;
      }
    } else {
      if (File(tmpPath).existsSync()) {
        try {
          File(tmpPath).deleteSync();
        } catch (_) {}
      }
      return false;
    }
  }

  /// Attempts downloading from a specific URL to tmpPath with retry
  Future<bool> _tryDownloadUrl(String url, String tmpPath, {int timeoutSec = 10}) async {
    for (int retry = 0; retry < 2; retry++) {
      if (_isCancelled) return false;
      try {
        final response = await _dio.download(
          url,
          tmpPath,
          options: Options(
            headers: const {
              'Connection': 'close',
              'User-Agent': 'Mozilla/5.0',
            },
            responseType: ResponseType.bytes,
            followRedirects: true,
            receiveTimeout: Duration(seconds: timeoutSec),
            sendTimeout: Duration(seconds: timeoutSec),
            validateStatus: (status) => status != null && status >= 200 && status < 300,
          ),
        );
        if (response.statusCode == 200 && File(tmpPath).existsSync() && File(tmpPath).lengthSync() > 500) {
          return true;
        }
      } catch (_) {
        if (retry == 0) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }
    }
    return false;
  }

  /// Downloads single verse on-demand if missing and caches locally
  static Future<String?> ensureVerseDownloaded(int surahId, int ayahId, {int? pageId}) async {
    try {
      final soundsDir = await getSoundsDirectory();
      final localPath = p.join(soundsDir.path, 'audio_${surahId}_$ayahId.mp3');
      if (isValidDiyanetAudioFile(File(localPath))) {
        return localPath;
      }

      final service = AudioDownloadService();
      final success = await service._downloadSingleVerseFile(
        VerseAudioInfo(pageId: pageId ?? 1, surahId: surahId, ayahId: ayahId),
        soundsDir.path,
      );

      if (success && isValidDiyanetAudioFile(File(localPath))) {
        return localPath;
      }
    } catch (e) {
      debugPrint('[AudioDownloadService] ensureVerseDownloaded error: $e');
    }
    return null;
  }
}

final audioDownloadServiceProvider = Provider<AudioDownloadService>((ref) {
  return AudioDownloadService();
});

final audioDownloadProgressStreamProvider = StreamProvider<AudioDownloadProgress>((ref) {
  final service = ref.watch(audioDownloadServiceProvider);
  return service.progressStream;
});
