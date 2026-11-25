import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tahrir/core/constants/app_constants.dart';
import 'package:tahrir/core/theme/app_colors.dart';
import 'package:tahrir/core/theme/app_typography.dart';
import 'package:tahrir/core/theme/theme_provider.dart';
import 'package:tahrir/features/reader/domain/content_block.dart';
import 'package:tahrir/features/reader/domain/reading_mode_hysteresis.dart';
import 'package:tahrir/features/reader/presentation/widgets/optical_reflow_view.dart';
import 'package:tahrir/features/reader/presentation/widgets/word_peek_sheet.dart';
import 'package:tahrir/features/reader/services/native_document_restorer.dart';
import 'package:tahrir/features/reader/services/optical_mask_cache_service.dart';
import 'package:tahrir/features/reader/services/reader_prefetch_queue.dart';

Uint8List _buildSyntheticAgedScanPng({
  int width = 320,
  int height = 220,
  bool twoColumns = false,
  double tiltSlope = 0.0,
}) {
  final image = img.Image(width, height);
  // Warm aged parchment background gradient (darker near top-left edge)
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final shade = 195 + ((x / width) * 35).round();
      image.setPixelRgba(x, y, shade, (shade * 0.92).round(), (shade * 0.78).round(), 255);
    }
  }

  void drawWordRect(int x0, int y0, int w, int h) {
    for (int dy = 0; dy < h; dy++) {
      for (int dx = 0; dx < w; dx++) {
        final yy = (y0 + dy + ((x0 + dx - width / 2) * tiltSlope)).round();
        final xx = x0 + dx;
        if (xx >= 0 && xx < width && yy >= 0 && yy < height) {
          image.setPixelRgba(xx, yy, 24, 20, 18, 255);
        }
      }
    }
  }

  if (!twoColumns) {
    // 3 lines with multiple spaced words
    for (int line = 0; line < 3; line++) {
      final ly = 40 + line * 42;
      drawWordRect(24, ly, 42, 16);
      drawWordRect(80, ly, 52, 16);
      drawWordRect(148, ly, 46, 16);
    }
  } else {
    // Left column (x: 20..120) and Right column (x: 195..295) with wide center gutter
    for (int line = 0; line < 3; line++) {
      final ly = 34 + line * 42;
      drawWordRect(22, ly, 40, 16);
      drawWordRect(76, ly, 44, 16);
      drawWordRect(198, ly, 40, 16);
      drawWordRect(252, ly, 42, 16);
    }
  }

  return Uint8List.fromList(img.encodePng(image, level: 5));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 1 Native Restoration, Optical Reflow, Hysteresis & Cache', () {
    test('Illumination flattening + Sauvola binarization isolates ink with transparent background',
        () {
      final png = _buildSyntheticAgedScanPng();
      final result = NativeDocumentRestorer.restoreAndSegmentSync(
        pagePngBytes: png,
      );

      expect(result.isValid, isTrue);
      expect(result.width, equals(320));
      expect(result.height, equals(220));
      expect(result.lines.length, greaterThanOrEqualTo(3));
      expect(result.wordBlobs.length, greaterThanOrEqualTo(6));

      final mask = img.decodePng(result.alphaMaskPngBytes)!;
      // Background corner pixel must be transparent (alpha == 0)
      final bgPixel = mask.getPixel(4, 4);
      expect(img.getAlpha(bgPixel), equals(0));

      // Known word ink center must have strong ink alpha (> 180)
      final inkPixel = mask.getPixel(40, 48);
      expect(img.getAlpha(inkPixel), greaterThan(180));
    });

    test('Projection-profile deskew detects tilted scan lines cleanly', () {
      final tiltedPng = _buildSyntheticAgedScanPng(
        width: 360,
        height: 240,
        tiltSlope: 0.055, // ~3.15 degrees
      );
      final result = NativeDocumentRestorer.restoreAndSegmentSync(
        pagePngBytes: tiltedPng,
        enableDeskew: true,
      );

      expect(result.isValid, isTrue);
      expect(result.detectedSkewDeg.abs(), greaterThan(0.5));
    });

    test('Two-column segmentation orders left column before right column', () {
      final twoColPng = _buildSyntheticAgedScanPng(
        width: 340,
        height: 220,
        twoColumns: true,
      );
      final result = NativeDocumentRestorer.restoreAndSegmentSync(
        pagePngBytes: twoColPng,
        enableDeskew: false,
      );

      expect(result.columnCount, equals(2));
      expect(result.wordBlobs.any((b) => b.columnIndex == 0), isTrue);
      expect(result.wordBlobs.any((b) => b.columnIndex == 1), isTrue);

      final firstCol1Idx =
          result.wordBlobs.indexWhere((b) => b.columnIndex == 1);
      final lastCol0Idx =
          result.wordBlobs.lastIndexWhere((b) => b.columnIndex == 0);
      expect(lastCol0Idx, lessThan(firstCol1Idx));
    });

    test('ReadingModeHysteresis prevents flickering at 0.75 and falls back below 0.72',
        () {
      expect(
        ReadingModeHysteresis.decideBookDefaultMode(
          initialPageConfidences: const [0.74, 0.76],
          hasDenseNonLatin: false,
        ),
        equals(ReaderDisplayMode.opticalReflow),
      );

      expect(
        ReadingModeHysteresis.decideBookDefaultMode(
          initialPageConfidences: const [0.88, 0.91],
          hasDenseNonLatin: false,
        ),
        equals(ReaderDisplayMode.textReflow),
      );

      // Hysteresis zone (0.75 is between 0.72 and 0.78): stays in textReflow
      expect(
        ReadingModeHysteresis.resolveEffectiveModeForPage(
          activeBookMode: ReaderDisplayMode.textReflow,
          userExplicitlySelectedMode: false,
          pageConfidence: 0.75,
          hasOpticalData: true,
        ),
        equals(ReaderDisplayMode.textReflow),
      );

      // Strictly below 0.72 triggers single-page fallback
      expect(
        ReadingModeHysteresis.resolveEffectiveModeForPage(
          activeBookMode: ReaderDisplayMode.textReflow,
          userExplicitlySelectedMode: false,
          pageConfidence: 0.68,
          hasOpticalData: true,
        ),
        equals(ReaderDisplayMode.opticalReflow),
      );

      // Explicit user lock overrides automatic fallback
      expect(
        ReadingModeHysteresis.resolveEffectiveModeForPage(
          activeBookMode: ReaderDisplayMode.textReflow,
          userExplicitlySelectedMode: true,
          pageConfidence: 0.50,
          hasOpticalData: true,
        ),
        equals(ReaderDisplayMode.textReflow),
      );
    });

    test('OpticalMaskCacheService enforces Disk LRU limit by evicting oldest masks',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('tahrir_lru_test_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final png = _buildSyntheticAgedScanPng(width: 120, height: 80);
      final restored = NativeDocumentRestorer.restoreAndSegmentSync(
        pagePngBytes: png,
        enableDeskew: false,
      );

      final entryBytesEstimate = restored.alphaMaskPngBytes.length + 512;
      final cache = OpticalMaskCacheService(
        maxCacheBytes: entryBytesEstimate * 2,
        overrideRootDir: tempDir,
      );

      final t0 = DateTime.utc(2026, 11, 25, 10, 0);
      await cache.putMask(
        filePath: 'book.pdf',
        pageIndex: 0,
        restoration: restored,
        now: t0,
      );
      await cache.putMask(
        filePath: 'book.pdf',
        pageIndex: 1,
        restoration: restored,
        now: t0.add(const Duration(seconds: 10)),
      );
      await cache.putMask(
        filePath: 'book.pdf',
        pageIndex: 2,
        restoration: restored,
        now: t0.add(const Duration(seconds: 20)),
      );

      expect(await cache.currentCacheBytes(), lessThanOrEqualTo(cache.maxCacheBytes));
      // Oldest page 0 must be evicted while newest page 2 survives
      expect(await cache.getMask(filePath: 'book.pdf', pageIndex: 0), isNull);
      expect(await cache.getMask(filePath: 'book.pdf', pageIndex: 2), isNotNull);
    });

    test('ReaderPrefetchQueue prioritizes [P, P+1, P+2, P+3, P-1] and cancels stale jumps',
        () async {
      expect(
        ReaderPrefetchQueue.buildPriorityOrder(activePage: 5, totalPages: 20),
        equals([5, 6, 7, 8, 4]),
      );

      final loadedPages = <int>[];
      late ReaderPrefetchQueue queue;
      queue = ReaderPrefetchQueue(
        loadPage: (page) async {
          loadedPages.add(page);
          if (page == 2) {
            // Simulate rapid user jump to page 10 while page 2 is running
            await queue.prioritizeNeighbors(activePage: 10, totalPages: 20);
          }
        },
      );
      addTearDown(queue.dispose);

      await queue.prioritizeNeighbors(activePage: 1, totalPages: 20);
      expect(loadedPages, containsAll([11, 12, 13, 9]));
      expect(loadedPages, isNot(contains(4)));
    });

    testWidgets(
        'OpticalReflowView, OpticalInkBlockWidget & WordPeekSheet render cleanly with theme ink',
        (tester) async {
      final png = _buildSyntheticAgedScanPng(width: 240, height: 140);
      final restored = NativeDocumentRestorer.restoreAndSegmentSync(
        pagePngBytes: png,
        enableDeskew: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                OpticalInkBlockWidget(
                  block: OpticalInkBlock(
                    title: 'Arapça Kesit',
                    alphaMaskPath: '',
                    rawAlphaMaskBytes: restored.alphaMaskPngBytes,
                    cropRect: const Rect.fromLTWH(20, 38, 120, 20),
                  ),
                ),
                Expanded(
                  child: OpticalReflowView(
                    alphaMaskPath: null,
                    inlineMaskBytes: restored.alphaMaskPngBytes,
                    wordBlobs: restored.wordBlobs,
                    imageWidth: restored.width,
                    imageHeight: restored.height,
                    themeState: const ReaderThemeState(
                      preset: TahrirThemePreset.parchment,
                      themeMode: ThemeMode.light,
                      fontFamily: TahrirFontFamily.literata,
                      fontSize: AppConstants.defaultFontSize,
                      lineHeight: AppConstants.defaultLineHeight,
                      sideMargin: AppConstants.defaultSideMargin,
                      bionicReadingEnabled: false,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(OpticalReflowView), findsOneWidget);
      expect(find.byType(OpticalInkBlockWidget), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WordPeekSheet(
              word: 'adalet',
              bookFilePath: 'sample://mukaddime_tahrir',
              pageNumber: 1,
              wordBoxes: [
                OcrWordBox(
                  word: 'adalet',
                  normalizedLeft: 0.1,
                  normalizedTop: 0.2,
                  normalizedWidth: 0.15,
                  normalizedHeight: 0.04,
                  confidence: 0.91,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('Orijinal Tarama Büyüteci'), findsOneWidget);
      expect(find.text('%91 Güven'), findsOneWidget);
    });
  });
}
