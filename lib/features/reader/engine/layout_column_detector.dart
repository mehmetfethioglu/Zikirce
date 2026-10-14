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

  /// Satırları dikey konuma (Y) göre ve aynı satır hizasındakileri yatay konuma (X) göre sıralar
  static List<PositionedTextLine> _sortLinesTopToBottom(List<PositionedTextLine> lines) {
    final sorted = List<PositionedTextLine>.from(lines);
    sorted.sort((a, b) {
      final diffY = a.bounds.top - b.bounds.top;
      if (diffY.abs() < 4.0) {
        return a.bounds.left.compareTo(b.bounds.left);
      }
      return diffY.compareTo(0);
    });
    return sorted;
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
      } else if (b.left >= midX * 1.02) {
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
