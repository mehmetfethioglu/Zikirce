import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:tahrir/features/reader/engine/layout_column_detector.dart';
import 'package:tahrir/features/reader/services/native_document_restorer.dart';
import 'package:tahrir/features/reader/services/scanned_pdf_ocr_service.dart';
import 'package:tahrir/features/reader/services/tesseract_line_verifier.dart';
import 'package:tahrir/features/reader/services/tesseract_model_manager.dart';

class _FakeLineVerifierGateway implements OcrLineVerifierGateway {
  final Map<String, TesseractLineResult> cannedResults;
  final List<TesseractLineVerificationRequest> recordedRequests = [];
  final bool available;

  _FakeLineVerifierGateway({
    this.cannedResults = const {},
    this.available = true,
  });

  @override
  bool get isAvailable => available;

  @override
  Future<TesseractLineVerificationBatchResult> verifyPageLines(
    TesseractLineVerificationRequest request,
  ) async {
    recordedRequests.add(request);
    return TesseractLineVerificationBatchResult(
      results: cannedResults,
      usedNativeTesseract: true,
    );
  }
}

TesseractModelSpec _specForBytes(String lang, Uint8List payload) {
  final digest = sha256.convert(payload).toString();
  return TesseractModelSpec(
    langCode: lang,
    fileName: '$lang.traineddata',
    downloadUrl: 'https://example.invalid/$lang.traineddata',
    expectedBytes: payload.length,
    expectedSha256: digest,
  );
}

Uint8List _createSyntheticPng({int width = 400, int height = 600}) {
  final image = img.Image(width, height);
  img.fill(image, img.getColor(255, 255, 255));
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  group('TesseractModelManager — SHA-256 & Atomik İndirme', () {
    late Directory tempRoot;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp('tahrir_tess_mgr_');
    });

    tearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    test('geçerli SHA-256 indirmede atomik taşıma ve hazır durumu doğrular',
        () async {
      final turBytes = Uint8List.fromList(utf8.encode('VALID_TUR_MODEL_v1'));
      final araBytes = Uint8List.fromList(utf8.encode('VALID_ARA_MODEL_v1'));

      final manager = TesseractModelManager(
        specs: [
          _specForBytes('tur', turBytes),
          _specForBytes('ara', araBytes),
        ],
        rootDirectoryProvider: () async => tempRoot,
        downloader: (url, partFile, onChunk) async {
          final bytes = url.path.contains('tur') ? turBytes : araBytes;
          await partFile.writeAsBytes(bytes, flush: true);
          onChunk(bytes.length);
        },
      );

      expect(await manager.areModelsReady(), isFalse);
      final ok = await manager.ensureModelsDownloadedInBackground();
      expect(ok, isTrue);
      expect(await manager.areModelsReady(), isTrue);
      expect(
        manager.stateNotifier.value.status,
        TesseractModelDownloadStatus.ready,
      );

      final tessDir = await manager.getTessdataDirectoryIfReady();
      expect(tessDir, isNotNull);
      expect(File('$tessDir/tur.traineddata').existsSync(), isTrue);
      expect(File('$tessDir/ara.traineddata').existsSync(), isTrue);
      expect(File('$tessDir/tur.traineddata.part').existsSync(), isFalse);

      manager.dispose();
    });

    test('bozuk SHA-256 verisini reddeder ve .part dosyasını temizler',
        () async {
      final turBytes = Uint8List.fromList(utf8.encode('VALID_TUR_MODEL_v1'));
      final corruptedBytes = Uint8List.fromList(utf8.encode('CORRUPTED_XXXX_v1'));

      final manager = TesseractModelManager(
        specs: [_specForBytes('tur', turBytes)],
        rootDirectoryProvider: () async => tempRoot,
        downloader: (url, partFile, onChunk) async {
          await partFile.writeAsBytes(corruptedBytes, flush: true);
          onChunk(corruptedBytes.length);
        },
      );

      final ok = await manager.ensureModelsDownloadedInBackground();
      expect(ok, isFalse);
      expect(await manager.areModelsReady(), isFalse);
      expect(
        manager.stateNotifier.value.status,
        TesseractModelDownloadStatus.failed,
      );

      final tessDir = await manager.resolveTessdataDirectory();
      expect(File('${tessDir.path}/tur.traineddata').existsSync(), isFalse);
      expect(File('${tessDir.path}/tur.traineddata.part').existsSync(), isFalse);

      manager.dispose();
    });

    test('eşzamanlı çağrılarda tek-uçuşlu (single-flight) indirme uygular',
        () async {
      final turBytes = Uint8List.fromList(utf8.encode('SINGLE_FLIGHT_DATA'));
      int downloadCalls = 0;

      final manager = TesseractModelManager(
        specs: [_specForBytes('tur', turBytes)],
        rootDirectoryProvider: () async => tempRoot,
        downloader: (url, partFile, onChunk) async {
          downloadCalls++;
          await Future<void>.delayed(const Duration(milliseconds: 25));
          await partFile.writeAsBytes(turBytes, flush: true);
          onChunk(turBytes.length);
        },
      );

      final results = await Future.wait([
        manager.ensureModelsDownloadedInBackground(),
        manager.ensureModelsDownloadedInBackground(),
        manager.ensureModelsDownloadedInBackground(),
      ]);

      expect(results, everyElement(isTrue));
      expect(downloadCalls, 1);

      manager.dispose();
    });
  });

  group('OcrEnsembleArbitrator — Seçici Hedefleme ve Hakemlik', () {
    test('temiz Türkçe satırları atlar, şüpheli ve düşük güvenli satırları seçer',
        () {
      final selected = OcrEnsembleArbitrator.selectSuspiciousMlKitLineIndices([
        (text: 'Kitabın birinci bölümü', minWordConfidence: 0.96),
        (text: 'k1tabm b0lumu burada', minWordConfidence: 0.91),
        (text: 'Okumak güzeldir', minWordConfidence: 0.68),
      ]);

      expect(selected, isNot(contains(0)));
      expect(selected, containsAll([1, 2]));
    });

    test('temiz Tesseract çıktısını seçer, bozuk Tesseract çıktısını reddeder',
        () {
      final win = OcrEnsembleArbitrator.arbitrateTurkishLine(
        mlKitText: 'k1tabm b0lumu burda',
        mlKitConfidence: 0.62,
        tesseractText: 'kitabın bölümü burada',
        tesseractConfidence: 88,
      );
      expect(win.acceptedTesseract, isTrue);
      expect(win.text, 'kitabın bölümü burada');

      final reject = OcrEnsembleArbitrator.arbitrateTurkishLine(
        mlKitText: 'kitabın bölümü burada',
        mlKitConfidence: 0.74,
        tesseractText: 'x#9@! qq^zz',
        tesseractConfidence: 48,
      );
      expect(reject.acceptedTesseract, isFalse);
      expect(reject.text, 'kitabın bölümü burada');
    });

    test('atlanan Arapça satırı metne yükseltir, okunaksız çizgiyi optik maskeye bırakır',
        () {
      final arabicEval = OcrEnsembleArbitrator.evaluateSkippedInkLine(
        tesseractText: 'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ',
        tesseractConfidence: 85,
      );
      expect(arabicEval.promote, isTrue);
      expect(arabicEval.isArabic, isTrue);

      final noiseEval = OcrEnsembleArbitrator.evaluateSkippedInkLine(
        tesseractText: '... ---',
        tesseractConfidence: 41,
      );
      expect(noiseEval.promote, isFalse);
    });
  });

  group('ScannedPdfOcrService — Faz 2 Hibrit Entegrasyon', () {
    late Directory tempRoot;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp('tahrir_phase2_e2e_');
    });

    tearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    test('şüpheli satırı düzeltir ve atlanan Arapça satırı metne terfi ettirir',
        () async {
      final turBytes = Uint8List.fromList(utf8.encode('READY_TUR'));
      final manager = TesseractModelManager(
        specs: [_specForBytes('tur', turBytes)],
        rootDirectoryProvider: () async => tempRoot,
        downloader: (url, partFile, onChunk) async {
          await partFile.writeAsBytes(turBytes, flush: true);
          onChunk(turBytes.length);
        },
      );
      expect(await manager.ensureModelsDownloadedInBackground(), isTrue);

      final fakeVerifier = _FakeLineVerifierGateway(
        cannedResults: const {
          'ml_1': TesseractLineResult(
            id: 'ml_1',
            text: 'tarih bilimi gelişmiştir',
            confidence: 89,
            succeeded: true,
          ),
          'skip_0': TesseractLineResult(
            id: 'skip_0',
            text: 'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ',
            confidence: 84,
            succeeded: true,
          ),
          'skip_1': TesseractLineResult(
            id: 'skip_1',
            text: '///',
            confidence: 32,
            succeeded: true,
          ),
        },
      );

      final service = ScannedPdfOcrService(
        tesseractModelManager: manager,
        lineVerifierGateway: fakeVerifier,
      );

      final restoration = DocumentRestorationResult(
        width: 400,
        height: 600,
        detectedSkewDeg: 0.0,
        columnCount: 1,
        restoredPngBytes: _createSyntheticPng(),
        alphaMaskPngBytes: Uint8List(0),
        lines: const [
          RestoredInkLine(
            x: 30,
            y: 40,
            width: 300,
            height: 24,
            columnIndex: 0,
            baselineY: 60,
            isParagraphStart: true,
          ),
          RestoredInkLine(
            x: 30,
            y: 90,
            width: 300,
            height: 24,
            columnIndex: 0,
            baselineY: 110,
            isParagraphStart: false,
          ),
          RestoredInkLine(
            x: 30,
            y: 160,
            width: 280,
            height: 28,
            columnIndex: 0,
            baselineY: 184,
            isParagraphStart: true,
          ),
          RestoredInkLine(
            x: 30,
            y: 230,
            width: 260,
            height: 24,
            columnIndex: 0,
            baselineY: 250,
            isParagraphStart: true,
          ),
        ],
        wordBlobs: const [],
        usedNativeFfi: false,
      );

      final lines = <PositionedTextLine>[
        const PositionedTextLine(
          text: 'Okumak güzeldir',
          bounds: ui.Rect.fromLTWH(30, 40, 300, 24),
          fontSize: 24,
        ),
        const PositionedTextLine(
          text: 't4rih bil1mi gelismistir',
          bounds: ui.Rect.fromLTWH(30, 90, 300, 24),
          fontSize: 24,
        ),
      ];
      final lowConfWords = <String, double>{'t4rih': 0.52, 'bil1mi': 0.58};

      final summary = await service.applyHybridLineVerification(
        restoration: restoration,
        lines: lines,
        mlKitLineMinConfidences: const [0.96, 0.52],
        mlKitLinePixelRects: const [
          ui.Rect.fromLTWH(30, 40, 300, 24),
          ui.Rect.fromLTWH(30, 90, 300, 24),
        ],
        pageLowConfidenceWords: lowConfWords,
        pageWidth: 400,
        pageHeight: 600,
        scaleX: 1.0,
        scaleY: 1.0,
      );

      expect(summary.upgradedMlLines, 1);
      expect(summary.promotedSkippedLines, 1);
      expect(lines.length, 3);
      expect(lines[1].text, 'tarih bilimi gelişmiştir');
      expect(lines[2].text, 'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ');
      expect(lowConfWords.containsKey('t4rih'), isFalse);

      // ml_0 (yüksek güvenli ve temiz) Tesseract'a hiç gönderilmemeli
      expect(fakeVerifier.recordedRequests, hasLength(1));
      final sentIds =
          fakeVerifier.recordedRequests.first.tasks.map((t) => t.id).toList();
      expect(sentIds, containsAll(['ml_1', 'skip_0', 'skip_1']));
      expect(sentIds, isNot(contains('ml_0')));

      // Terfi edilen skip_0 artık kapsanmış olmalı, skip_1 hâlâ kapsanmamış kalmalı
      final remainingSkipped = OcrEnsembleArbitrator.selectSkippedInkLines(
        restoration: restoration,
        ocrLines: lines,
        pageWidth: 400,
        pageHeight: 600,
      );
      expect(remainingSkipped, hasLength(1));
      expect(remainingSkipped.first.y, 230);

      manager.dispose();
    });

    test('native Tesseract veya modeller hazır değilse güvenle Faz 1 akışına düşer',
        () async {
      final turBytes = Uint8List.fromList(utf8.encode('READY_TUR'));
      final readyManager = TesseractModelManager(
        specs: [_specForBytes('tur', turBytes)],
        rootDirectoryProvider: () async => tempRoot,
        downloader: (url, partFile, onChunk) async {
          await partFile.writeAsBytes(turBytes, flush: true);
          onChunk(turBytes.length);
        },
      );
      expect(await readyManager.ensureModelsDownloadedInBackground(), isTrue);

      final unavailableGateway = _FakeLineVerifierGateway(available: false);
      final service = ScannedPdfOcrService(
        tesseractModelManager: readyManager,
        lineVerifierGateway: unavailableGateway,
      );

      final restoration = DocumentRestorationResult(
        width: 400,
        height: 600,
        detectedSkewDeg: 0.0,
        columnCount: 1,
        restoredPngBytes: _createSyntheticPng(),
        alphaMaskPngBytes: Uint8List(0),
        lines: const [],
        wordBlobs: const [],
        usedNativeFfi: false,
      );

      final lines = <PositionedTextLine>[
        const PositionedTextLine(
          text: 't4rih b0zuldu',
          bounds: ui.Rect.fromLTWH(30, 90, 260, 24),
          fontSize: 24,
        ),
      ];

      final summary = await service.applyHybridLineVerification(
        restoration: restoration,
        lines: lines,
        mlKitLineMinConfidences: const [0.55],
        mlKitLinePixelRects: const [ui.Rect.fromLTWH(30, 90, 260, 24)],
        pageLowConfidenceWords: <String, double>{'t4rih': 0.55},
        pageWidth: 400,
        pageHeight: 600,
        scaleX: 1.0,
        scaleY: 1.0,
      );

      expect(summary.upgradedMlLines, 0);
      expect(summary.promotedSkippedLines, 0);
      expect(unavailableGateway.recordedRequests, isEmpty);

      readyManager.dispose();
    });
  });
}
