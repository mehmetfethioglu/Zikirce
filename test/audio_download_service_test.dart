import 'package:flutter_test/flutter_test.dart';
import 'package:zikirce/core/services/audio_download_service.dart';
import 'package:zikirce/core/services/audio_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioSyncService Juz & Page Calculation Tests', () {
    test('Juz 1 page range should be 1 to 21', () {
      final (start, end) = AudioSyncService.getJuzPageRange(1);
      expect(start, equals(1));
      expect(end, equals(21));
    });

    test('Juz 2 page range should be 22 to 41', () {
      final (start, end) = AudioSyncService.getJuzPageRange(2);
      expect(start, equals(22));
      expect(end, equals(41));
    });

    test('Juz 29 page range should be 562 to 581', () {
      final (start, end) = AudioSyncService.getJuzPageRange(29);
      expect(start, equals(562));
      expect(end, equals(581));
    });

    test('Juz 30 page range should be 582 to 604', () {
      final (start, end) = AudioSyncService.getJuzPageRange(30);
      expect(start, equals(582));
      expect(end, equals(604));
    });
  });

  group('AudioDownloadService URLs and Hafiz Selection Tests', () {
    test('Standard page should use ar_osmanSahin', () {
      final url = AudioDownloadService.getDiyanetAudioUrl(1, 1, pageId: 1);
      expect(url, equals('https://webdosya.diyanet.gov.tr/kuran/kuranikerim/Sound/ar_osmanSahin/1_1.mp3'));
    });

    test('Page 289 should use ar_mehmetCevik', () {
      final url = AudioDownloadService.getDiyanetAudioUrl(17, 76, pageId: 289);
      expect(url, equals('https://webdosya.diyanet.gov.tr/kuran/kuranikerim/Sound/ar_mehmetCevik/17_76.mp3'));
    });

    test('Page 292 should use ar_mehmetCevik', () {
      final url = AudioDownloadService.getDiyanetAudioUrl(18, 74, pageId: 292);
      expect(url, equals('https://webdosya.diyanet.gov.tr/kuran/kuranikerim/Sound/ar_mehmetCevik/18_74.mp3'));
    });

    test('Page 293 should switch back to ar_osmanSahin', () {
      final url = AudioDownloadService.getDiyanetAudioUrl(18, 75, pageId: 293);
      expect(url, equals('https://webdosya.diyanet.gov.tr/kuran/kuranikerim/Sound/ar_osmanSahin/18_75.mp3'));
    });

    test('Fallback EveryAyah URL should have 3-digit zero padding', () {
      final url = AudioDownloadService.getFallbackAudioUrl(1, 7);
      expect(url, equals('https://everyayah.com/data/Alafasy_128kbps/001007.mp3'));

      final url2 = AudioDownloadService.getFallbackAudioUrl(114, 6);
      expect(url2, equals('https://everyayah.com/data/Alafasy_128kbps/114006.mp3'));
    });
  });

  group('AudioDownloadProgress Model Tests', () {
    test('copyWith updates fields correctly', () {
      const initial = AudioDownloadProgress();
      expect(initial.completed, equals(0));
      expect(initial.total, equals(0));
      expect(initial.isDownloading, isFalse);

      final updated = initial.copyWith(
        completed: 100,
        total: 6236,
        progress: 100 / 6236,
        statusText: '%1 indiriliyor...',
        isDownloading: true,
      );

      expect(updated.completed, equals(100));
      expect(updated.total, equals(6236));
      expect(updated.isDownloading, isTrue);
      expect(updated.statusText, equals('%1 indiriliyor...'));
    });
  });
}
