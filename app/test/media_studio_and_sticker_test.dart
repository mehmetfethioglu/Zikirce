import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zamera/models/inspector_colorimetry.dart';
import 'package:zamera/models/media_archive_item.dart';
import 'package:zamera/painters/checkerboard_and_lift_painter.dart';
import 'package:zamera/screens/media_studio_screen.dart';
import 'package:zamera/services/zamera_media_archive_store.dart';
import 'package:zamera/widgets/studio/cinema_video_player_view.dart';
import 'package:zamera/widgets/studio/sticker_studio_sheet.dart';
import 'package:zamera_capture/zamera_capture.dart';
import 'package:zamera_video/zamera_video.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const captureChannel = MethodChannel('com.akarworks.zamera/capture_probe');
  final Uint8List valid1x1Png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  );

  group('ZameraMediaArchiveStore & Colorimetry Histogram', () {
    test('persists across reload, prunes missing files, filters 6 categories, and deletes natively', () async {
      SharedPreferences.setMockInitialValues({});
      final existingPaths = <String>{
        '/mock/art.jpg',
        '/mock/art.dng',
        '/mock/portrait.jpg',
        '/mock/clip.mp4',
        '/mock/st1.png',
      };
      final deletedCalls = <Map<String, String?>>[];

      final store = ZameraMediaArchiveStore(
        fileExistsPredicate: existingPaths.contains,
        deleteNativeAsset: ({String? filePath, String? mediaStoreUri}) async {
          deletedCalls.add({
            'filePath': filePath,
            'mediaStoreUri': mediaStoreUri,
          });
          return true;
        },
      );
      addTearDown(store.dispose);

      await store.load();
      expect(store.items, isEmpty);

      final artPhoto = ZameraMediaItem.fromPhotoCapture(
        const CapturePhotoResult(
          cameraId: '2',
          jpegPath: '/mock/art.jpg',
          oemJpegPath: '/mock/art_oem.jpg',
          dngPath: '/mock/art.dng',
          mediaStoreJpegUri: 'content://media/external/images/1',
          outputWidth: 4096,
          outputHeight: 3072,
          iso: 100,
          exposureTimeNs: 8000000,
          solvedCctKelvin: 5500,
          colorSpaceTag: 'Display P3',
          rustIspActive: true,
        ),
        isPortrait: false,
      );
      final portraitPhoto = ZameraMediaItem.fromPhotoCapture(
        const CapturePhotoResult(
          cameraId: '2',
          jpegPath: '/mock/portrait.jpg',
          portraitDepthActive: true,
          outputWidth: 3072,
          outputHeight: 4096,
          iso: 200,
        ),
        isPortrait: true,
        portraitAperture: 2.0,
      );
      final videoItem = ZameraMediaItem.fromVideoRecording(
        const ZameraVideoRecordingResult(
          videoPath: '/mock/clip.mp4',
          durationMs: 4200,
          fileSizeBytes: 18 * 1024 * 1024,
          width: 3840,
          height: 2160,
          fps: 60,
          bitrateMbps: 80.0,
          codec: 'HEVC',
          profile: 'APPLE_LOG',
          colorStandard: 'BT2020',
          colorTransfer: 'HLG',
          droppedFrames: 0,
        ),
      );
      final stickerItem = ZameraMediaItem.fromStickerCutout(
        pngPath: '/mock/st1.png',
        width: 512,
        height: 640,
        hasWhiteOutline: true,
        sourceMediaId: artPhoto.id,
      );

      await store.addOrUpdate(artPhoto);
      await store.addOrUpdate(portraitPhoto);
      await store.addOrUpdate(videoItem);
      await store.addOrUpdate(stickerItem);
      await store.toggleFavorite(artPhoto.id);

      expect(store.items.length, 4);
      expect(store.itemsForFilter(ZameraArchiveFilter.all).length, 4);
      expect(store.itemsForFilter(ZameraArchiveFilter.photos).length, 2);
      expect(store.itemsForFilter(ZameraArchiveFilter.videos).length, 1);
      expect(store.itemsForFilter(ZameraArchiveFilter.portrait).length, 1);
      expect(store.itemsForFilter(ZameraArchiveFilter.raw).length, 1);
      expect(store.itemsForFilter(ZameraArchiveFilter.stickers).length, 1);

      existingPaths.remove('/mock/portrait.jpg');
      final reloaded = ZameraMediaArchiveStore(
        fileExistsPredicate: existingPaths.contains,
      );
      addTearDown(reloaded.dispose);
      await reloaded.load();

      expect(reloaded.items.length, 3);
      expect(
        reloaded.items.any((e) => e.id == portraitPhoto.id),
        isFalse,
        reason: 'Missing files on disk must be pruned automatically during load()',
      );
      final reloadedArt = reloaded.items.firstWhere((e) => e.id == artPhoto.id);
      expect(reloadedArt.isFavorite, isTrue);
      expect(reloadedArt.dngPath, '/mock/art.dng');

      await store.remove(artPhoto.id, deleteDiskFiles: true);
      expect(deletedCalls.length, 3);
      expect(deletedCalls[0]['filePath'], '/mock/art.jpg');
      expect(deletedCalls[1]['filePath'], '/mock/art.dng');
      expect(deletedCalls[2]['filePath'], '/mock/art_oem.jpg');
    });

    test('computeRgbaHistogram64 bins opaque RGB pixels and skips alpha=0 transparent pixels', () {
      final bytes = Uint8List.fromList([
        0, 0, 0, 0,
        0, 0, 0, 0,
        255, 0, 0, 255,
        255, 0, 0, 255,
      ]);
      final hist = computeRgbaHistogram64(bytes, 2, 2);
      expect(hist.redBins.length, 64);
      expect(hist.redBins[63], closeTo(1.0, 1e-6));
      expect(hist.greenBins[0], closeTo(1.0, 1e-6));
      expect(hist.blueBins[0], closeTo(1.0, 1e-6));
      expect(hist.shadowClipRatio, closeTo(0.0, 1e-6));
      expect(hist.highlightClipRatio, closeTo(1.0, 1e-6));
    });
  });

  group('MediaStudioScreen & StickerStudioSheet Widget Workflows', () {
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDir = await Directory.systemTemp.createTemp('zamera_studio_test_');
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(captureChannel, null);
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } on FileSystemException catch (e) {
        debugPrint('Windows temp dir cleanup deferred: $e');
      }
    });

    testWidgets('supports grid filtering, sticker shelf quick copy/share, RAW share, and Sticker Studio style toggle', (tester) async {
      final photoFile = File('${tempDir.path}/art.png')..writeAsBytesSync(valid1x1Png);
      final dngFile = File('${tempDir.path}/art.dng')..writeAsBytesSync([0x49, 0x49, 0x2A, 0x00]);
      final stFile = File('${tempDir.path}/st1.png')..writeAsBytesSync(valid1x1Png);

      final recorded = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(captureChannel, (call) async {
        recorded.add(call);
        if (call.method == 'extractSubjectCutoutPng') {
          final args = call.arguments as Map<dynamic, dynamic>;
          final outline = args['addWhiteOutline'] == true;
          final outFile = File('${tempDir.path}/cut_${outline ? 'out' : 'tr'}.png')
            ..writeAsBytesSync(valid1x1Png);
          return {
            'pngPath': outFile.path,
            'cutoutPngPath': outFile.path,
            'width': 320,
            'height': 480,
            'copiedToClipboard': false,
            'savedToGallery': args['saveToGallery'] == true,
          };
        }
        if (call.method == 'copyPngToClipboard' || call.method == 'shareMediaFiles') {
          return true;
        }
        return null;
      });

      final artItem = ZameraMediaItem.fromPhotoCapture(
        CapturePhotoResult(
          cameraId: '2',
          jpegPath: photoFile.path,
          dngPath: dngFile.path,
          outputWidth: 4000,
          outputHeight: 3000,
          iso: 100,
          exposureTimeNs: 10000000,
          solvedCctKelvin: 5400,
          colorSpaceTag: 'sRGB',
          rustIspActive: true,
        ),
        isPortrait: false,
      );
      final stickerItem = ZameraMediaItem.fromStickerCutout(
        pngPath: stFile.path,
        width: 300,
        height: 400,
        hasWhiteOutline: false,
      );

      final store = ZameraMediaArchiveStore(
        initialItems: [artItem, stickerItem],
        fileExistsPredicate: (p) => File(p).existsSync(),
      );
      addTearDown(store.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaStudioScreen(
            archiveRepository: store,
            initialMediaId: artItem.id,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Open Info & Histogram panel -> verify EXIF + separate JPEG and RAW DNG share buttons
      await tester.tap(find.byKey(const ValueKey('studio_tool_info_btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('studio_exif_card')), findsOneWidget);
      expect(find.byKey(const ValueKey('studio_share_jpeg_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('studio_share_dng_btn')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const ValueKey('studio_share_dng_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('studio_share_dng_btn')));
      await tester.pump();
      expect(
        recorded.any(
          (c) =>
              c.method == 'shareMediaFiles' &&
              (c.arguments['filePaths'] as List).contains(dngFile.path),
        ),
        isTrue,
      );

      // 2. Toggle Grid -> filter Stickers -> test Sticker Shelf 1-tap Copy & Share
      await tester.tap(find.byKey(const ValueKey('studio_toggle_grid_btn')));
      await tester.pumpAndSettle();
      final filterListScrollable = find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('archive_filter_stickers')),
        140,
        scrollable: filterListScrollable,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('archive_filter_stickers')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ValueKey('sticker_shelf_copy_${stickerItem.id}')));
      await tester.pump();
      expect(
        recorded.any(
          (c) =>
              c.method == 'copyPngToClipboard' &&
              c.arguments['pngPath'] == stFile.path,
        ),
        isTrue,
      );

      await tester.tap(find.byKey(ValueKey('sticker_shelf_share_${stickerItem.id}')));
      await tester.pump();
      expect(
        recorded.any(
          (c) =>
              c.method == 'shareMediaFiles' &&
              (c.arguments['filePaths'] as List).contains(stFile.path),
        ),
        isTrue,
      );

      // Return to Studio view
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('archive_filter_all')),
        -140,
        scrollable: filterListScrollable,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('archive_filter_all')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('studio_toggle_grid_btn')));
      await tester.pumpAndSettle();

      // 3. Open Sticker Studio -> toggles Saf Şeffaf vs Beyaz Konturlu Sticker -> copy -> archive
      await tester.tap(find.byKey(const ValueKey('studio_tool_sticker_btn')));
      await tester.pumpAndSettle();
      expect(find.byType(StickerStudioSheet), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is TransparencyCheckerboardPainter,
        ),
        findsWidgets,
      );

      expect(
        recorded.any(
          (c) =>
              c.method == 'extractSubjectCutoutPng' &&
              c.arguments['addWhiteOutline'] == false,
        ),
        isTrue,
      );

      await tester.tap(find.byKey(const ValueKey('sticker_style_outline')));
      await tester.pumpAndSettle();
      expect(
        recorded.any(
          (c) =>
              c.method == 'extractSubjectCutoutPng' &&
              c.arguments['addWhiteOutline'] == true,
        ),
        isTrue,
      );

      await tester.tap(find.byKey(const ValueKey('sticker_copy_btn')));
      await tester.pump();
      expect(recorded.where((c) => c.method == 'copyPngToClipboard').length, greaterThanOrEqualTo(2));

      await tester.tap(find.byKey(const ValueKey('sticker_save_shelf_btn')));
      await tester.pumpAndSettle();
      expect(store.itemsForFilter(ZameraArchiveFilter.stickers).length, 2);
    });

    testWidgets('renders CinemaVideoPlayerView telemetry and archives extracted frame', (tester) async {
      final mp4File = File('${tempDir.path}/clip.mp4')..writeAsBytesSync([0x00, 0x00, 0x00, 0x18]);
      final extractedFrame = File('${tempDir.path}/frame.png')..writeAsBytesSync(valid1x1Png);

      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(captureChannel, (call) async {
        calls.add(call);
        if (call.method == 'extractVideoFrameJpeg') {
          return {
            'jpegPath': extractedFrame.path,
            'width': 3840,
            'height': 2160,
          };
        }
        return null;
      });

      final videoItem = ZameraMediaItem.fromVideoRecording(
        ZameraVideoRecordingResult(
          videoPath: mp4File.path,
          durationMs: 5000,
          fileSizeBytes: 24 * 1024 * 1024,
          width: 3840,
          height: 2160,
          fps: 60,
          bitrateMbps: 100.0,
          codec: 'HEVC',
          profile: 'APPLE_LOG',
          colorStandard: 'BT2020',
          colorTransfer: 'HLG',
          droppedFrames: 0,
        ),
      );
      final store = ZameraMediaArchiveStore(
        initialItems: [videoItem],
        fileExistsPredicate: (p) => File(p).existsSync(),
      );
      addTearDown(store.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaStudioScreen(
            archiveRepository: store,
            initialMediaId: videoItem.id,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CinemaVideoPlayerView), findsOneWidget);
      expect(find.byKey(const ValueKey('video_smpte_timecode')), findsOneWidget);
      expect(find.byKey(const ValueKey('video_telemetry_card')), findsOneWidget);
      expect(find.text('60 FPS'), findsOneWidget);
      expect(find.text('HEVC'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const ValueKey('video_capture_frame_btn')));
      await tester.tap(find.byKey(const ValueKey('video_capture_frame_btn')));
      await tester.pumpAndSettle();

      expect(calls.any((c) => c.method == 'extractVideoFrameJpeg'), isTrue);
      expect(store.itemsForFilter(ZameraArchiveFilter.photos).length, 1);
      expect(store.items.first.primaryPath, extractedFrame.path);
    });
  });
}
