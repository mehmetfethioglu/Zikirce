import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import '../domain/content_block.dart';
import '../engine/snippet_detector.dart';

/// Arka plan Isolate içinde görsel kırpma parametreleri
class _CropParams {
  final Uint8List pageImageBytes;
  final Rect boundingBox;
  final double scaleX;
  final double scaleY;
  final String outputPath;

  _CropParams({
    required this.pageImageBytes,
    required this.boundingBox,
    required this.scaleX,
    required this.scaleY,
    required this.outputPath,
  });
}

/// PDF sayfalarını 300 DPI yüksek çözünürlükte render edip
/// sadece istenen koordinat alanlarını keserek (crop) geçici önbelleğe kaydeden servis.
class PdfSnippetCropper {
  const PdfSnippetCropper();

  /// Belirtilen PDF sayfasını ve aday koordinat alanlarını işleyerek
  /// yüksek çözünürlüklü kırpılmış blokları oluşturur.
  Future<List<InteractiveSnippetBlock>> cropCandidates({
    required String filePath,
    required int pageIndex,
    required List<SnippetCandidate> candidates,
    required double originalPageWidth,
    required double originalPageHeight,
  }) async {
    if (candidates.isEmpty) return [];

    final file = File(filePath);
    if (!await file.exists()) {
      return _generateFallbackSnippets(candidates);
    }

    try {
      final cacheDir = await _getCacheDirectory();
      final targetDpiScale = 300.0 / 72.0; // 300 DPI rasterization çarpanı (~4.16x)

      // 1. PDF Sayfasını 300 DPI Çözünürlükte Render Et
      final doc = await pdfx.PdfDocument.openFile(filePath);
      final page = await doc.getPage(pageIndex + 1);

      final renderWidth = (page.width * targetDpiScale).roundToDouble();
      final renderHeight = (page.height * targetDpiScale).roundToDouble();

      final pageImage = await page.render(
        width: renderWidth,
        height: renderHeight,
        format: pdfx.PdfPageImageFormat.png,
        backgroundColor: '#FFFFFF',
      );

      await page.close();
      await doc.close();

      if (pageImage == null || pageImage.bytes.isEmpty) {
        return _generateFallbackSnippets(candidates);
      }

      final scaleX = renderWidth / (originalPageWidth > 0 ? originalPageWidth : page.width);
      final scaleY = renderHeight / (originalPageHeight > 0 ? originalPageHeight : page.height);

      final blocks = <InteractiveSnippetBlock>[];

      for (final candidate in candidates) {
        // Önbellek dosya adı oluştur
        final hashKey = '${p.basename(filePath)}_p${pageIndex}_${candidate.type.name}_${candidate.boundingBox.left.toInt()}_${candidate.boundingBox.top.toInt()}';
        final fileName = 'snippet_${hashKey.hashCode.toRadixString(16)}.png';
        final outFilePath = p.join(cacheDir.path, fileName);
        final outFile = File(outFilePath);

        Uint8List croppedBytes;

        if (await outFile.exists()) {
          // Önbellekten hızlı oku
          croppedBytes = await outFile.readAsBytes();
        } else {
          // Isolate içinde 300 DPI kırpma yap
          final params = _CropParams(
            pageImageBytes: pageImage.bytes,
            boundingBox: candidate.boundingBox,
            scaleX: scaleX,
            scaleY: scaleY,
            outputPath: outFilePath,
          );

          croppedBytes = await compute(_isolateCropAndSave, params);
        }

        blocks.add(InteractiveSnippetBlock(
          type: candidate.type,
          title: candidate.title,
          subtitle: candidate.subtitle,
          croppedImagePath: outFilePath,
          rawBytes: croppedBytes,
          boundingBox: candidate.boundingBox,
          fallbackText: candidate.rawText,
        ));
      }

      return blocks;
    } catch (e) {
      debugPrint('PdfSnippetCropper error: $e');
      return _generateFallbackSnippets(candidates);
    }
  }

  /// Tekil bir başlık kesitini 300 DPI kırpar
  Future<CalligraphyHeaderBlock?> cropHeader({
    required String filePath,
    required int pageIndex,
    required SnippetCandidate candidate,
    required double originalPageWidth,
    required double originalPageHeight,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) return null;

    try {
      final cacheDir = await _getCacheDirectory();
      final targetDpiScale = 300.0 / 72.0;

      final doc = await pdfx.PdfDocument.openFile(filePath);
      final page = await doc.getPage(pageIndex + 1);

      final renderWidth = (page.width * targetDpiScale).roundToDouble();
      final renderHeight = (page.height * targetDpiScale).roundToDouble();

      final pageImage = await page.render(
        width: renderWidth,
        height: renderHeight,
        format: pdfx.PdfPageImageFormat.png,
        backgroundColor: '#FFFFFF',
      );

      await page.close();
      await doc.close();

      if (pageImage == null || pageImage.bytes.isEmpty) return null;

      final scaleX = renderWidth / (originalPageWidth > 0 ? originalPageWidth : page.width);
      final scaleY = renderHeight / (originalPageHeight > 0 ? originalPageHeight : page.height);

      final hashKey = '${p.basename(filePath)}_header_p${pageIndex}_${candidate.boundingBox.top.toInt()}';
      final fileName = 'header_${hashKey.hashCode.toRadixString(16)}.png';
      final outFilePath = p.join(cacheDir.path, fileName);
      final outFile = File(outFilePath);

      Uint8List croppedBytes;
      if (await outFile.exists()) {
        croppedBytes = await outFile.readAsBytes();
      } else {
        final params = _CropParams(
          pageImageBytes: pageImage.bytes,
          boundingBox: candidate.boundingBox,
          scaleX: scaleX,
          scaleY: scaleY,
          outputPath: outFilePath,
        );
        croppedBytes = await compute(_isolateCropAndSave, params);
      }

      return CalligraphyHeaderBlock(
        title: candidate.title,
        croppedImagePath: outFilePath,
        rawBytes: croppedBytes,
        boundingBox: candidate.boundingBox,
      );
    } catch (e) {
      debugPrint('PdfSnippetCropper cropHeader error: $e');
      return null;
    }
  }

  /// Isolate içinde çalışan saf görsel çözümleme ve kırpma fonksiyonu
  static Uint8List _isolateCropAndSave(_CropParams params) {
    final decoded = img.decodeImage(params.pageImageBytes);
    if (decoded == null) {
      return Uint8List(0);
    }

    final cropX = (params.boundingBox.left * params.scaleX).round().clamp(0, decoded.width - 1);
    final cropY = (params.boundingBox.top * params.scaleY).round().clamp(0, decoded.height - 1);
    final cropW = (params.boundingBox.width * params.scaleX).round().clamp(1, decoded.width - cropX);
    final cropH = (params.boundingBox.height * params.scaleY).round().clamp(1, decoded.height - cropY);

    final cropped = img.copyCrop(
      decoded,
      cropX,
      cropY,
      cropW,
      cropH,
    );

    final pngBytes = Uint8List.fromList(img.encodePng(cropped, level: 6));

    // Diske kaydet
    try {
      final file = File(params.outputPath);
      file.writeAsBytesSync(pngBytes, flush: true);
    } catch (_) {}

    return pngBytes;
  }

  /// Önbellek klasörünü hazırlar
  Future<Directory> _getCacheDirectory() async {
    final temp = await getTemporaryDirectory();
    final snippetDir = Directory(p.join(temp.path, 'tahrir_snippets'));
    if (!await snippetDir.exists()) {
      await snippetDir.create(recursive: true);
    }
    return snippetDir;
  }

  /// Sanal / fallback aday bloklar
  List<InteractiveSnippetBlock> _generateFallbackSnippets(List<SnippetCandidate> candidates) {
    return candidates.map((c) {
      return InteractiveSnippetBlock(
        type: c.type,
        title: c.title,
        subtitle: c.subtitle,
        croppedImagePath: '',
        fallbackText: c.rawText,
        boundingBox: c.boundingBox,
      );
    }).toList();
  }
}
