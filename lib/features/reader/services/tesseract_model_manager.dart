import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Tekil bir Tesseract `tessdata_best` dil modelinin indirme ve SHA-256 doğrulama sözleşmesi.
@immutable
class TesseractModelSpec {
  final String langCode;
  final String fileName;
  final String downloadUrl;
  final int expectedBytes;
  final String expectedSha256;

  const TesseractModelSpec({
    required this.langCode,
    required this.fileName,
    required this.downloadUrl,
    required this.expectedBytes,
    required this.expectedSha256,
  });
}

/// Model indirme yaşam döngüsü durumu.
enum TesseractModelDownloadStatus {
  notDownloaded,
  downloading,
  ready,
  failed,
}

/// İsteğe bağlı UI/tanı gözlemcileri için anlık indirme durumu.
@immutable
class TesseractModelState {
  final TesseractModelDownloadStatus status;
  final int downloadedBytes;
  final int totalBytes;
  final String? activeLanguage;
  final String? errorMessage;

  const TesseractModelState({
    this.status = TesseractModelDownloadStatus.notDownloaded,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.activeLanguage,
    this.errorMessage,
  });

  double get progress =>
      totalBytes <= 0 ? 0.0 : (downloadedBytes / totalBytes).clamp(0.0, 1.0);

  TesseractModelState copyWith({
    TesseractModelDownloadStatus? status,
    int? downloadedBytes,
    int? totalBytes,
    String? activeLanguage,
    bool clearActiveLanguage = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return TesseractModelState(
      status: status ?? this.status,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      activeLanguage:
          clearActiveLanguage ? null : (activeLanguage ?? this.activeLanguage),
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Test edilebilir akış tabanlı indirme geri çağrısı.
typedef TesseractStreamDownloader = Future<void> Function(
  Uri url,
  File targetPartFile,
  void Function(int bytesChunk) onChunk,
);

/// `crypto.sha256.startChunkedConversion` için ek paket gerektirmeyen hafif sink.
class _DigestAccumulatorSink implements Sink<Digest> {
  Digest? digest;

  @override
  void add(Digest data) {
    digest = data;
  }

  @override
  void close() {}
}

/// Sabitlenmiş `tesseract-ocr/tessdata_best` commit SHA'sından (~19.1 MiB) yalnızca
/// ilk taranmış PDF açılışında arka planda model indiren ve her baytı SHA-256 ile
/// doğrulayıp atomik olarak yerleştiren çevrimdışı model yöneticisi.
///
/// AAB boyutunu ~98 MB altında tutmak için `.traineddata` dosyaları APK/AAB içine gömülmez.
class TesseractModelManager {
  static const String pinnedCommitSha =
      'e12c65a915945e4c28e237a9b52bc4a8f39a0cec';

  static const List<TesseractModelSpec> defaultSpecs = [
    TesseractModelSpec(
      langCode: 'tur',
      fileName: 'tur.traineddata',
      downloadUrl:
          'https://raw.githubusercontent.com/tesseract-ocr/tessdata_best/$pinnedCommitSha/tur.traineddata',
      expectedBytes: 7456265,
      expectedSha256:
          'e0c3338dc17503dc7d335a507c9ae01b2b46cfd07561171e1e1ac55d85e8e438',
    ),
    TesseractModelSpec(
      langCode: 'ara',
      fileName: 'ara.traineddata',
      downloadUrl:
          'https://raw.githubusercontent.com/tesseract-ocr/tessdata_best/$pinnedCommitSha/ara.traineddata',
      expectedBytes: 12603724,
      expectedSha256:
          'ab9d157d8e38ca00e7e39c7d5363a5239e053f5b0dbdb3167dde9d8124335896',
    ),
  ];

  static final TesseractModelManager instance = TesseractModelManager();

  final List<TesseractModelSpec> specs;
  final Future<Directory> Function() _rootDirectoryProvider;
  final TesseractStreamDownloader _downloader;

  final ValueNotifier<TesseractModelState> stateNotifier =
      ValueNotifier<TesseractModelState>(const TesseractModelState());

  final Map<String, ({int length, int modifiedMs})> _verifiedCache = {};
  Future<bool>? _inFlightDownload;
  bool _disposed = false;

  TesseractModelManager({
    this.specs = defaultSpecs,
    Future<Directory> Function()? rootDirectoryProvider,
    TesseractStreamDownloader? downloader,
  })  : _rootDirectoryProvider =
            rootDirectoryProvider ?? getApplicationSupportDirectory,
        _downloader = downloader ?? _defaultStreamDownload;

  int get totalRequiredBytes =>
      specs.fold<int>(0, (sum, spec) => sum + spec.expectedBytes);

  Future<Directory> resolveTessdataDirectory() async {
    final root = await _rootDirectoryProvider();
    return Directory(p.join(root.path, 'tesseract', 'tessdata'));
  }

  /// Tüm dil dosyaları diskte mevcutsa ve SHA-256 doğrulamasından geçtiyse `true` döner.
  Future<bool> areModelsReady() async {
    return (await getTessdataDirectoryIfReady()) != null;
  }

  /// Tüm modeller doğrulanmış şekilde hazırsa `tessdata` klasör yolunu, aksi halde `null` döner.
  Future<String?> getTessdataDirectoryIfReady() async {
    if (specs.isEmpty) return null;
    try {
      final tessDir = await resolveTessdataDirectory();
      if (!await tessDir.exists()) return null;

      for (final spec in specs) {
        final file = File(p.join(tessDir.path, spec.fileName));
        final valid = await _verifyExistingFile(file, spec);
        if (!valid) {
          return null;
        }
      }
      if (!_disposed &&
          stateNotifier.value.status != TesseractModelDownloadStatus.ready) {
        _emitState(
          TesseractModelState(
            status: TesseractModelDownloadStatus.ready,
            downloadedBytes: totalRequiredBytes,
            totalBytes: totalRequiredBytes,
          ),
        );
      }
      return tessDir.path;
    } catch (e) {
      debugPrint('TesseractModelManager readiness check error: $e');
      return null;
    }
  }

  /// Eksik/bozuk modelleri tek uçuşlu (single-flight) kilit altında arka planda indirir,
  /// streaming SHA-256 ile doğrular ve `.part` dosyasından atomik olarak taşır.
  ///
  /// Asla istisna fırlatmaz; indirme sürerken UI/okuma bloklanmaz.
  Future<bool> ensureModelsDownloadedInBackground() {
    if (_disposed) return Future.value(false);
    final existing = _inFlightDownload;
    if (existing != null) return existing;

    final future = _downloadMissingModelsInternal();
    _inFlightDownload = future.whenComplete(() {
      _inFlightDownload = null;
    });
    return _inFlightDownload!;
  }

  Future<bool> _downloadMissingModelsInternal() async {
    try {
      final tessDir = await resolveTessdataDirectory();
      if (!await tessDir.exists()) {
        await tessDir.create(recursive: true);
      }

      final totalBytes = totalRequiredBytes;
      int completedPriorBytes = 0;

      // Önce mevcut sağlıklı dosyaların boyutunu hesapla
      final specsToDownload = <TesseractModelSpec>[];
      for (final spec in specs) {
        final target = File(p.join(tessDir.path, spec.fileName));
        if (await _verifyExistingFile(target, spec)) {
          completedPriorBytes += spec.expectedBytes;
        } else {
          specsToDownload.add(spec);
        }
      }

      if (specsToDownload.isEmpty) {
        _emitState(
          TesseractModelState(
            status: TesseractModelDownloadStatus.ready,
            downloadedBytes: totalBytes,
            totalBytes: totalBytes,
          ),
        );
        return true;
      }

      for (final spec in specsToDownload) {
        final targetFile = File(p.join(tessDir.path, spec.fileName));
        final partFile = File('${targetFile.path}.part');
        int currentModelBytes = 0;

        _emitState(
          TesseractModelState(
            status: TesseractModelDownloadStatus.downloading,
            downloadedBytes: completedPriorBytes,
            totalBytes: totalBytes,
            activeLanguage: spec.langCode,
          ),
        );

        try {
          if (await partFile.exists()) {
            await partFile.delete();
          }

          await _downloader(
            Uri.parse(spec.downloadUrl),
            partFile,
            (chunkLen) {
              currentModelBytes += chunkLen;
              _emitState(
                TesseractModelState(
                  status: TesseractModelDownloadStatus.downloading,
                  downloadedBytes: completedPriorBytes + currentModelBytes,
                  totalBytes: totalBytes,
                  activeLanguage: spec.langCode,
                ),
              );
            },
          );

          final isValidPart = await _verifyFileStrict(partFile, spec);
          if (!isValidPart) {
            if (await partFile.exists()) {
              await partFile.delete();
            }
            _emitState(
              TesseractModelState(
                status: TesseractModelDownloadStatus.failed,
                downloadedBytes: completedPriorBytes,
                totalBytes: totalBytes,
                activeLanguage: spec.langCode,
                errorMessage:
                    '${spec.fileName} SHA-256 doğrulaması başarısız oldu.',
              ),
            );
            return false;
          }

          if (await targetFile.exists()) {
            await targetFile.delete();
          }
          await partFile.rename(targetFile.path);
          final stat = await targetFile.stat();
          _verifiedCache[targetFile.path] = (
            length: stat.size,
            modifiedMs: stat.modified.millisecondsSinceEpoch,
          );
          completedPriorBytes += spec.expectedBytes;
        } catch (e) {
          debugPrint(
            'TesseractModelManager download error (${spec.fileName}): $e',
          );
          try {
            if (await partFile.exists()) {
              await partFile.delete();
            }
          } catch (cleanupErr) {
            debugPrint(
              'TesseractModelManager part cleanup warning: $cleanupErr',
            );
          }
          _emitState(
            TesseractModelState(
              status: TesseractModelDownloadStatus.failed,
              downloadedBytes: completedPriorBytes,
              totalBytes: totalBytes,
              activeLanguage: spec.langCode,
              errorMessage: e.toString(),
            ),
          );
          return false;
        }
      }

      _emitState(
        TesseractModelState(
          status: TesseractModelDownloadStatus.ready,
          downloadedBytes: totalBytes,
          totalBytes: totalBytes,
        ),
      );
      return true;
    } catch (e) {
      debugPrint('TesseractModelManager fatal error: $e');
      _emitState(
        TesseractModelState(
          status: TesseractModelDownloadStatus.failed,
          downloadedBytes: 0,
          totalBytes: totalRequiredBytes,
          errorMessage: e.toString(),
        ),
      );
      return false;
    }
  }

  Future<bool> _verifyExistingFile(
    File file,
    TesseractModelSpec spec,
  ) async {
    if (!await file.exists()) {
      _verifiedCache.remove(file.path);
      return false;
    }
    final stat = await file.stat();
    if (stat.size != spec.expectedBytes) {
      _verifiedCache.remove(file.path);
      return false;
    }
    final cached = _verifiedCache[file.path];
    if (cached != null &&
        cached.length == stat.size &&
        cached.modifiedMs == stat.modified.millisecondsSinceEpoch) {
      return true;
    }
    final ok = await _verifyFileStrict(file, spec);
    if (ok) {
      _verifiedCache[file.path] = (
        length: stat.size,
        modifiedMs: stat.modified.millisecondsSinceEpoch,
      );
    } else {
      _verifiedCache.remove(file.path);
    }
    return ok;
  }

  Future<bool> _verifyFileStrict(
    File file,
    TesseractModelSpec spec,
  ) async {
    if (!await file.exists()) return false;
    final length = await file.length();
    if (length != spec.expectedBytes) return false;

    final sink = _DigestAccumulatorSink();
    final input = sha256.startChunkedConversion(sink);
    try {
      await for (final chunk in file.openRead()) {
        input.add(chunk);
      }
    } finally {
      input.close();
    }
    final actualHex = sink.digest?.toString().toLowerCase() ?? '';
    return actualHex == spec.expectedSha256.toLowerCase();
  }

  void _emitState(TesseractModelState next) {
    if (_disposed) return;
    stateNotifier.value = next;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _verifiedCache.clear();
    stateNotifier.dispose();
  }

  static Future<void> _defaultStreamDownload(
    Uri url,
    File targetPartFile,
    void Function(int bytesChunk) onChunk,
  ) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20)
      ..userAgent = 'TahrirReader/1.0';
    IOSink? sink;
    try {
      final request = await client.getUrl(url);
      request.followRedirects = true;
      request.maxRedirects = 5;
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'HTTP ${response.statusCode} while fetching $url',
          uri: url,
        );
      }
      sink = targetPartFile.openWrite(mode: FileMode.writeOnly);
      await for (final chunk in response) {
        sink.add(chunk);
        onChunk(chunk.length);
      }
      await sink.flush();
    } finally {
      try {
        await sink?.close();
      } catch (e) {
        debugPrint('TesseractModelManager sink close warning: $e');
      }
      client.close(force: true);
    }
  }
}
