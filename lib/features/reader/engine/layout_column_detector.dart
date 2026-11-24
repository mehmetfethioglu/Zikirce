import 'package:flutter/material.dart';

/// PDF sayfasından çıkarılan koordinatlı satır verisi
@immutable
class PositionedTextLine {
  final String text;
  final Rect bounds;
  final double fontSize;

  const PositionedTextLine({
    required this.text,
    required this.bounds,
    this.fontSize = 12.0,
  });
}

/// Sayfa Mizanpaj Türü
enum PageLayoutType {
  singleColumn,
  twoColumn,
  complexGrid,
}

/// PDF sayfalarında koordinat bazlı sütun tespiti ve çok sütunlu okuma sırası düzenleyicisi
class LayoutColumnDetector {
  const LayoutColumnDetector._();

  /// Sayfadaki satırları koordinatlarına göre analiz eder.
  /// Çift sütunlu sayfalarda önce sol sütunu yukarıdan aşağıya,
  /// ardından sağ sütunu yukarıdan aşağıya sıralı akışa dönüştürür.
  static List<PositionedTextLine> orderLinesByReadingFlow({
    required List<PositionedTextLine> rawLines,
    required double pageWidth,
    required double pageHeight,
  }) {
    if (rawLines.isEmpty) return rawLines;

    // Sayfa üst ve alt marjinlerde yalnızca tekil sayfa numaralarını ayıkla;
    // sayfa altındaki dipnot satırlarını (y <= 0.985) kesinlikle koru.
    final topMargin = pageHeight * 0.04;
    final bottomMargin = pageHeight * 0.965;
    final isolatedPageNumRegex = RegExp(r'^\s*[\-–—_~•\[\(]*\s*\d{1,4}\s*[\-–—_~•\]\)]*\s*$');
    final footnoteStartRegex = RegExp(
      r'^\s*(?:\[\d{1,4}\]|\(\d{1,4}\)|[¹²³⁴⁵⁶⁷⁸⁹⁰]+|\*|†|\d{1,4}[\.\):—\-])\s*\S*',
      unicode: true,
    );

    final contentLines = rawLines.where((line) {
      final y = line.bounds.top;
      final trimmed = line.text.trim();
      if (trimmed.isEmpty) return false;
      if (footnoteStartRegex.hasMatch(trimmed)) {
        return true;
      }
      if ((y < topMargin || y > bottomMargin) && isolatedPageNumRegex.hasMatch(trimmed)) {
        return false;
      }
      return y >= pageHeight * 0.02 && y <= pageHeight * 0.985;
    }).toList();

    if (contentLines.length < 4) {
      // Satır sayısı çok azsa doğrudan Y eksenine göre (aynı satırda ise X'e göre) sırala
      return _sortLinesTopToBottom(contentLines);
    }

    final layoutType = detectLayoutType(contentLines, pageWidth);

    if (layoutType == PageLayoutType.singleColumn) {
      // Tek sütun: Doğrudan yukarıdan aşağıya sırala
      return _sortLinesTopToBottom(contentLines);
    }

    // Çift sütunlu mizanpaj
    final columnMidpoint = pageWidth * 0.50;
    final fullWidthThreshold = pageWidth * 0.68;

    final fullWidthSpans = <PositionedTextLine>[];
    final leftColumnLines = <PositionedTextLine>[];
    final rightColumnLines = <PositionedTextLine>[];

    for (final line in contentLines) {
      final bounds = line.bounds;

      // Sayfa boyunca uzanan tam genişlikli başlıklar
      if (bounds.width >= fullWidthThreshold) {
        fullWidthSpans.add(line);
      } else if (bounds.center.dx < columnMidpoint) {
        // Sol sütun
        leftColumnLines.add(line);
      } else {
        // Sağ sütun
        rightColumnLines.add(line);
      }
    }

    // Sol ve sağ sütunları kendi içlerinde yukarıdan aşağıya sırala
    final sortedLeft = _sortLinesTopToBottom(leftColumnLines);
    final sortedRight = _sortLinesTopToBottom(rightColumnLines);
    final sortedFullWidth = _sortLinesTopToBottom(fullWidthSpans);

    // Tam genişlikli üst başlıkları en başa al, ardından sol sütun, ardından sağ sütun
    final ordered = <PositionedTextLine>[];

    // Üstte kalan başlıklar
    final topHeaders = sortedFullWidth.where((l) => l.bounds.top < pageHeight * 0.25).toList();
    final bottomFullSpans = sortedFullWidth.where((l) => l.bounds.top >= pageHeight * 0.25).toList();

    ordered.addAll(topHeaders);
    ordered.addAll(sortedLeft);
    ordered.addAll(sortedRight);
    ordered.addAll(bottomFullSpans);

    return ordered;
  }

  /// Satırları dikey merkeze (Y) göre geçişli (transitive) sıralar ve aynı görsel satırdaki
  /// parçalanmış yatay kutuları soldan sağa birleştirerek tek satır haline getirir.
  static List<PositionedTextLine> _sortLinesTopToBottom(List<PositionedTextLine> lines) {
    if (lines.length <= 1) return List<PositionedTextLine>.from(lines);

    // 1. Kesin geçişli (transitive) sıralama: Önce dikey merkez (center.dy), eşitse yatay sol (left)
    final sorted = List<PositionedTextLine>.from(lines)
      ..sort((a, b) {
        final cmpY = a.bounds.center.dy.compareTo(b.bounds.center.dy);
        if (cmpY != 0) return cmpY;
        return a.bounds.left.compareTo(b.bounds.left);
      });

    // 2. Aynı görsel satıra düşen parçalı OCR/PDF kutularını kümeler halinde topla
    final rows = <List<PositionedTextLine>>[];
    for (final line in sorted) {
      if (rows.isEmpty) {
        rows.add([line]);
        continue;
      }

      final currentRow = rows.last;
      final firstInRow = currentRow.first;
      final refHeight = firstInRow.bounds.height > 0 ? firstInRow.bounds.height : 14.0;
      final tolerance = (refHeight * 0.45).clamp(4.0, 10.0);

      if ((line.bounds.center.dy - firstInRow.bounds.center.dy).abs() <= tolerance) {
        currentRow.add(line);
      } else {
        rows.add([line]);
      }
    }

    // 3. Her satır kümesini kendi içinde soldan sağa sırala ve yatay parçaları birleştir
    final result = <PositionedTextLine>[];
    for (final row in rows) {
      if (row.length == 1) {
        result.add(row.first);
        continue;
      }

      row.sort((a, b) => a.bounds.left.compareTo(b.bounds.left));

      // Aynı satırdaki yatay parçaları tek bir PositionedTextLine olarak birleştir
      var mergedText = row.first.text.trimRight();
      var minLeft = row.first.bounds.left;
      var minTop = row.first.bounds.top;
      var maxRight = row.first.bounds.right;
      var maxBottom = row.first.bounds.bottom;
      var maxFontSize = row.first.fontSize;

      for (int i = 1; i < row.length; i++) {
        final frag = row[i];
        final fragText = frag.text.trimLeft();
        if (fragText.isEmpty) continue;

        if (mergedText.endsWith('-') || mergedText.endsWith('=')) {
          mergedText = '$mergedText$fragText';
        } else {
          mergedText = '$mergedText $fragText';
        }

        if (frag.bounds.left < minLeft) minLeft = frag.bounds.left;
        if (frag.bounds.top < minTop) minTop = frag.bounds.top;
        if (frag.bounds.right > maxRight) maxRight = frag.bounds.right;
        if (frag.bounds.bottom > maxBottom) maxBottom = frag.bounds.bottom;
        if (frag.fontSize > maxFontSize) maxFontSize = frag.fontSize;
      }

      result.add(PositionedTextLine(
        text: mergedText,
        bounds: Rect.fromLTRB(minLeft, minTop, maxRight, maxBottom),
        fontSize: maxFontSize,
      ));
    }

    return result;
  }

  /// Sayfanın tek sütun mu yoksa çift sütun mu olduğunu istatistiksel ve oluk (gutter) analizinden tespit eder
  static PageLayoutType detectLayoutType(
    List<PositionedTextLine> lines,
    double pageWidth,
  ) {
    if (lines.length < 8 || pageWidth <= 0) {
      return PageLayoutType.singleColumn;
    }

    final midX = pageWidth * 0.50;
    int strictLeftCount = 0;
    int strictRightCount = 0;
    int spanningMidpointCount = 0;

    for (final line in lines) {
      final b = line.bounds;
      // Ortayı aşan satır (Solu ortanın solunda, sağı ortanın sağında)
      if (b.left < midX * 0.90 && b.right > midX * 1.10) {
        spanningMidpointCount++;
      } else if (b.right <= midX * 0.98) {
        strictLeftCount++;
      } else if (b.left >= midX * 0.02 + midX) {
        strictRightCount++;
      }
    }

    final totalColumnLines = strictLeftCount + strictRightCount;
    final totalLines = lines.length;

    // Gerçek çift sütun şartı:
    // 1. Sol ve sağ sütunda en az dörder satır olmalı
    // 2. Satırların en az %60'ı bu iki ayrı sütuna ait olmalı
    // 3. Ortayı boydan boya kesen satır oranı %25'i geçmemeli
    if (strictLeftCount >= 4 &&
        strictRightCount >= 4 &&
        (totalColumnLines / totalLines) >= 0.60 &&
        (spanningMidpointCount / totalLines) <= 0.25) {
      return PageLayoutType.twoColumn;
    }

    return PageLayoutType.singleColumn;
  }
}
