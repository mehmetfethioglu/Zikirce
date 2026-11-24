import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahrir/core/errors/app_error.dart';
import 'package:tahrir/core/services/changelog_service.dart';
import 'package:tahrir/core/services/reading_notification_service.dart';
import 'package:tahrir/features/marginalia/services/dictionary_service.dart';
import 'package:tahrir/features/reader/engine/epub_parser_engine.dart';
import 'package:tahrir/features/reader/engine/pdf_reflow_engine.dart';
import 'package:tahrir/features/reader/engine/text_segmenter.dart';
import 'package:tahrir/features/reader/services/ambient_audio_service.dart';
import 'package:tahrir/features/reader/services/offline_ai_service.dart';

void main() {
  group('Tahrir Unit & Smoke Tests', () {
    test('TextSegmenter deHyphenate removes line-break hyphens correctly', () {
      const sample = 'Tahrir ile yapılan tahrir-\nler zihni açar.';
      final cleaned = TextSegmenter.deHyphenate(sample);
      expect(cleaned, equals('Tahrir ile yapılan tahrirler zihni açar.'));
    });

    test('DictionaryService local lookup finds root entries, multi-word phrases, and stems inflected Turkish words', () {
      final service = DictionaryService();
      final entry = service.lookup('tahrir');
      expect(entry.word, equals('Tahrir'));
      expect(entry.origin, contains('Arapça'));

      // Morphological suffix stripping & consonant softening test
      final inflected1 = service.lookup('hikmetin');
      expect(inflected1.word, equals('Hikmet'));

      final inflected2 = service.lookup('şerhleri');
      expect(inflected2.word, equals('Şerh'));

      // Classical legal & historical terms with suffixes
      expect(service.lookup('İmâmet').word, equals('İmâmet'));
      expect(service.lookup('vâcibdir').word, equals('Vâcib'));
      expect(service.lookup('müessesesinin').word, equals('Müessese'));

      // Multi-word selection in reader
      final phraseMatch = service.lookup('Hilâfet ve İmâmet');
      expect(phraseMatch.word, contains('Hilâfet'));

      // Multi-pass suffix stripping ('kitaplarımızdan' -> 'Kitap')
      expect(service.lookup('kitaplarımızdan').word, equals('Kitap'));

      // Dynamic morphological analysis for general inflected words (never static placeholder)
      final dynamicMorph = service.lookup('yürüyüşlerimizden');
      expect(dynamicMorph.origin, contains('Kök:'));

      final searchResults = service.search('belagat');
      expect(searchResults, isNotEmpty);
    });

    test('OfflineAiService extracts key concepts, TextRank summaries, and studyQuestions without network', () {
      const aiService = OfflineAiService();
      final insights = aiService.analyzeText(
        'Kutadgu Bilig eseri adalet, akıl ve nizam üzerine kurulmuş bir Türk klasiğidir. '
        'Yusuf Has Hacib bu eserde devlet yönetiminde hikmet ve faziletin önemini vurgular. '
        'İrfan sahibi insan, bilgisini toplumun saadeti için kullanan kimsedir.',
      );
      expect(insights.keyConcepts, isNotEmpty);
      expect(insights.summaryBulletPoints, isNotEmpty);
      expect(insights.studyQuestions, isNotEmpty);
    });

    test('EpubParserEngine parseMarkdownOrTxt fallback produces structured chapters', () async {
      const epubEngine = EpubParserEngine();
      final chapters = await epubEngine.parseMarkdownOrTxt('sample://markdown_test.md');
      expect(chapters, isNotEmpty);
      expect(chapters.first.paragraphs, isNotEmpty);
    });

    test('OfflineAiService buildConcordance indexes concept occurrences across pages and extracts co-occurring concepts', () {
      const aiService = OfflineAiService();
      final pageMap = <int, String>{
        1: 'Devlet yönetiminde adalet mülkün temelidir. Hikmet ve erdem hükümdarın rehberidir.',
        2: 'Adaletin olmadığı yerde zulüm baş gösterir. Akıl ve hikmet birleştiğinde saadet doğar.',
        3: 'Adaletli bir nizam toplumun huzurunu korur ve fazileti yüceltir.',
      };

      final radar = aiService.buildConcordance(
        concept: 'adaletin',
        pageTexts: pageMap,
      );
      expect(radar.stemUsed, equals('adalet'));
      expect(radar.totalOccurrences, greaterThanOrEqualTo(3));
      expect(radar.firstSeenPage, equals(1));
      expect(radar.matches.length, equals(3));
      expect(radar.relatedConcepts, isNotEmpty);
    });

    test('AmbientAudioService synthesizes 44.1kHz zero-seam circular loop WAVs across 10 studio soundscapes', () {
      expect(AmbientSoundType.values.length, equals(11)); // none + 10 soundscapes
      final neyWav = AmbientAudioService.generateSeamlessWavSync(AmbientSoundType.ney);
      final bd = ByteData.sublistView(neyWav);
      final sampleRate = bd.getUint32(24, Endian.little);
      expect(sampleRate, equals(44100));

      // Check loop boundary continuity (last sample vs first sample jump is tiny)
      final firstSample = bd.getInt16(44, Endian.little);
      final lastSample = bd.getInt16(neyWav.length - 2, Endian.little);
      expect((firstSample - lastSample).abs(), lessThan(4500));
    });

    test('ReadingNotificationService evaluateNecessity suppresses spam when goal met and alerts when streak at risk', () {
      final suppressed = ReadingNotificationService.evaluateNecessity(
        isEnabled: true,
        onlyWhenGoalIncomplete: true,
        streakRiskAlertEnabled: true,
        streakDays: 5,
        todayMinutesRead: 25,
        dailyGoalMinutes: 20,
        currentBookTitle: 'Kutadgu Bilig',
        currentHour: 21,
      );
      expect(suppressed.shouldNotify, isFalse);
      expect(suppressed.reason, equals(NotificationNecessityReason.notNeededGoalMet));

      final atRisk = ReadingNotificationService.evaluateNecessity(
        isEnabled: true,
        onlyWhenGoalIncomplete: true,
        streakRiskAlertEnabled: true,
        streakDays: 7,
        todayMinutesRead: 0,
        dailyGoalMinutes: 20,
        currentBookTitle: 'Mukaddime',
        currentHour: 20,
      );
      expect(atRisk.shouldNotify, isTrue);
      expect(atRisk.reason, equals(NotificationNecessityReason.streakAtRiskEvening));
      expect(atRisk.title, contains('7 Günlük'));
    });

    test('ChangelogService provides bilingual TR and EN release notes (Zikirce_ Standard)', () {
      expect(ChangelogService.releases, isNotEmpty);
      const service = ChangelogService();
      final latest = service.latestRelease;
      expect(latest.version, startsWith('v1.'));
      expect(latest.highlightsTr, isNotEmpty);
      expect(latest.highlightsEn, isNotEmpty);
    });

    test('Result type handles success and failure folds cleanly', () {
      const success = Result.success(42);
      expect(success.isSuccess, isTrue);
      expect(success.dataOrNull, equals(42));

      final failure = Result<int>.failure(const GeneralError('Hata'));
      expect(failure.isFailure, isTrue);
      expect(failure.errorOrNull?.message, equals('Hata'));
    });

    test('PdfReflowEngine extracts sample pages (Kutadgu Bilig & Mukaddime) and flags text presence', () async {
      const engine = PdfReflowEngine();
      final pageData = await engine.extractPage('sample://kutadgu_bilig', 0);
      expect(pageData.pageNumber, equals(1));
      expect(pageData.hasTextContent, isTrue);
      expect(pageData.paragraphs, isNotEmpty);

      final mukaddimePage = await engine.extractPage('sample://mukaddime_tahrir', 0);
      expect(mukaddimePage.pageNumber, equals(1));
      expect(mukaddimePage.footnotes.length, greaterThanOrEqualTo(2));
      expect(mukaddimePage.contentBlocks, isNotEmpty);
    });
  });
}
