import 'package:flutter/material.dart';
import '../domain/content_block.dart';
import 'layout_column_detector.dart';

/// Tespit edilen sorunlu alan / kesit adayı
@immutable
class SnippetCandidate {
  final SnippetType type;
  final String title;
  final String? subtitle;
  final String? rawText;
  final Rect boundingBox;
  final double confidence;

  const SnippetCandidate({
    required this.type,
    required this.title,
    this.subtitle,
    this.rawText,
    required this.boundingBox,
    this.confidence = 1.0,
  });
}

/// PDF sayfalarında sorunlu alanları (Bozuk CMap Arapça, kaligrafi başlık, tablo, dipnot)
/// otomatik tespit eden ve kesme koordinatlarını (Bounding Box) belirleyen analiz motoru.
class SnippetDetector {
  const SnippetDetector._();

  /// Satırları ve sayfa boyutlarını tarayarak sorunlu bölgeleri tespit eder
  static List<SnippetCandidate> detectSnippets({
    required List<PositionedTextLine> lines,
    required double pageWidth,
    required double pageHeight,
  }) {
    final candidates = <SnippetCandidate>[];
    if (lines.isEmpty || pageWidth <= 0 || pageHeight <= 0) {
      return candidates;
    }

    // 1. Sayfa Başındaki Kaligrafik Başlık Tespiti (Üst %20 dilimi)
    final headerCandidate = _detectCalligraphyHeader(lines, pageWidth, pageHeight);
    if (headerCandidate != null) {
      candidates.add(headerCandidate);
    }

    // 2. Tablo ve Vektörel Şema Tespiti
    final tableCandidates = _detectTablesAndDiagrams(lines, pageWidth, pageHeight);
    candidates.addAll(tableCandidates);

    // 3. Bozuk CMap / Anlamsız ASCII Glif Dizileri (Arapça Hat / İbareler)
    final corruptedCmapCandidates = _detectCorruptedCmapBlocks(lines, pageWidth, pageHeight);
    candidates.addAll(corruptedCmapCandidates);

    // 4. Sayfa Altı Küçük Puntolu Dipnot Alanı Tespiti
    final footnoteCandidate = _detectFootnoteRegion(lines, pageWidth, pageHeight);
    if (footnoteCandidate != null) {
      candidates.add(footnoteCandidate);
    }

    return candidates;
  }

  /// Sayfa başındaki standart dışı kaligrafik başlık bölgesini tespit eder
  static SnippetCandidate? _detectCalligraphyHeader(
    List<PositionedTextLine> lines,
    double pageWidth,
    double pageHeight,
  ) {
    final topLines = lines.where((l) => l.bounds.top < pageHeight * 0.22).toList();
    if (topLines.isEmpty) return null;

    for (final line in topLines) {
      final text = line.text.trim();
      // Bozuk başlık sembolleri veya bilinen süslü kaligrafi desenleri
      final isCalligraphicArtifact = RegExp(r'(?:[Jj]\s*[\?C]|[cC][tT]\?|</[Jj]|fi[çkrmsdgntplvbzğ])', unicode: true).hasMatch(text) ||
          isGarbageNoise(text);

      if (isCalligraphicArtifact && text.length < 80) {
        // Genişletilmiş Bounding Box (Kenar boşlukları ile)
        final left = (line.bounds.left - 12).clamp(0.0, pageWidth);
        final top = (line.bounds.top - 8).clamp(0.0, pageHeight);
        final right = (line.bounds.right + 12).clamp(0.0, pageWidth);
        final bottom = (line.bounds.bottom + 8).clamp(0.0, pageHeight);

        return SnippetCandidate(
          type: SnippetType.calligraphyTitle,
          title: 'Kaligrafik Başlık Kesiti',
          rawText: text,
          boundingBox: Rect.fromLTRB(left, top, right, bottom),
          confidence: 0.90,
        );
      }
    }

    return null;
  }

  /// Tablo ve matris yapılarını tespit eder (Hizalanmış sütunlar, sekme/çizgi desenleri)
  static List<SnippetCandidate> _detectTablesAndDiagrams(
    List<PositionedTextLine> lines,
    double pageWidth,
    double pageHeight,
  ) {
    final results = <SnippetCandidate>[];
    final tableLines = <PositionedTextLine>[];

    for (final line in lines) {
      final text = line.text;
      // Tablo göstergeleri: Çoklu boşluk/sekme ayrımı, kutu çizimleri (+, |, -), ardışık sayı dizilimleri
      final hasColumnSeparators = RegExp(r'(\t|\s{3,}[^\s]+\s{3,}|[\|│├┤┬┴┼])').hasMatch(text);
      final hasMatrixNumbers = RegExp(r'\b\d+[\.,]?\d*\s{3,}\d+[\.,]?\d*\b').hasMatch(text);

      if (hasColumnSeparators || hasMatrixNumbers) {
        tableLines.add(line);
      } else {
        if (tableLines.length >= 3) {
          results.add(_buildBoundingBoxFromLines(
            tableLines,
            SnippetType.table,
            'Tablo Kesiti',
            pageWidth,
            pageHeight,
          ));
        }
        tableLines.clear();
      }
    }

    if (tableLines.length >= 3) {
      results.add(_buildBoundingBoxFromLines(
        tableLines,
        SnippetType.table,
        'Tablo Kesiti',
        pageWidth,
        pageHeight,
      ));
    }

    return results;
  }

  /// Bozuk CMap / ASCII glif gürültüsü içeren Arapça hat/ibare bloklarını tespit eder
  static List<SnippetCandidate> _detectCorruptedCmapBlocks(
    List<PositionedTextLine> lines,
    double pageWidth,
    double pageHeight,
  ) {
    final results = <SnippetCandidate>[];
    final corruptedGroup = <PositionedTextLine>[];

    for (final line in lines) {
      final text = line.text.trim();
      if (isGarbageNoise(text)) {
        corruptedGroup.add(line);
      } else {
        if (corruptedGroup.isNotEmpty) {
          results.add(_buildBoundingBoxFromLines(
            corruptedGroup,
            SnippetType.arabicCalligraphy,
            'Orijinal İbare / Hat Kesiti',
            pageWidth,
            pageHeight,
          ));
          corruptedGroup.clear();
        }
      }
    }

    if (corruptedGroup.isNotEmpty) {
      results.add(_buildBoundingBoxFromLines(
        corruptedGroup,
        SnippetType.arabicCalligraphy,
        'Orijinal İbare / Hat Kesiti',
        pageWidth,
        pageHeight,
      ));
    }

    return results;
  }

  /// Sayfa altındaki dipnot alanını tespit eder
  static SnippetCandidate? _detectFootnoteRegion(
    List<PositionedTextLine> lines,
    double pageWidth,
    double pageHeight,
  ) {
    final bottomLines = lines.where((l) => l.bounds.top >= pageHeight * 0.70).toList();
    if (bottomLines.isEmpty) return null;

    final footnoteLines = <PositionedTextLine>[];
    bool inFootnotes = false;

    for (final line in bottomLines) {
      final text = line.text.trim();
      final hasFootnoteMarker = RegExp(r'^(?:[-—_]{3,}|\d{1,2}[.\s:—\)]|\[\d{1,2}\]|\*|¹|²|³|⁴|⁵)').hasMatch(text);
      if (hasFootnoteMarker) {
        inFootnotes = true;
      }
      if (inFootnotes) {
        footnoteLines.add(line);
      }
    }

    if (footnoteLines.length >= 2) {
      return _buildBoundingBoxFromLines(
        footnoteLines,
        SnippetType.footnote,
        'Dipnot Alanı Kesiti',
        pageWidth,
        pageHeight,
      );
    }

    return null;
  }

  /// Bir grup satırdan kapsayıcı ve marjinli Bounding Box hesaplar
  static SnippetCandidate _buildBoundingBoxFromLines(
    List<PositionedTextLine> group,
    SnippetType type,
    String title,
    double pageWidth,
    double pageHeight,
  ) {
    double minX = pageWidth;
    double minY = pageHeight;
    double maxX = 0;
    double maxY = 0;

    final textBuffer = StringBuffer();

    for (final line in group) {
      final b = line.bounds;
      if (b.left < minX) minX = b.left;
      if (b.top < minY) minY = b.top;
      if (b.right > maxX) maxX = b.right;
      if (b.bottom > maxY) maxY = b.bottom;
      textBuffer.writeln(line.text);
    }

    // 12px kenar marjini ekle
    final left = (minX - 12).clamp(0.0, pageWidth);
    final top = (minY - 10).clamp(0.0, pageHeight);
    final right = (maxX + 12).clamp(0.0, pageWidth);
    final bottom = (maxY + 10).clamp(0.0, pageHeight);

    return SnippetCandidate(
      type: type,
      title: title,
      rawText: textBuffer.toString().trim(),
      boundingBox: Rect.fromLTRB(left, top, right, bottom),
      confidence: 0.95,
    );
  }

  /// Bir metnin bozuk CMap / anlamsız ASCII glif kirliliği olup olmadığını kontrol eder
  static bool isGarbageNoise(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    // Bilinen bozuk sembol kalıpları
    if (RegExp(r'(?:[oO0]\s*[,.]{2,}\s*|[Gg]i\s*[,.]{2,}|J\s+J\s*[,.]{2,}|j,tlj|\b0fa\b|\\\s*rı|[,\.]{3,}\s*(?:tP|J|\d+S|\bhş|41S))', unicode: true).hasMatch(trimmed)) {
      return true;
    }

    int symbolCount = 0;
    int letterCount = 0;
    for (final rune in trimmed.runes) {
      final char = String.fromCharCode(rune);
      if (RegExp(r'[<>;:_~^\\|!*+=.,"\u0027\-\/\[\]\{\}\(\)]').hasMatch(char)) {
        symbolCount++;
      } else if (RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(char)) {
        letterCount++;
      }
    }

    final total = symbolCount + letterCount;
    if (total == 0) return false;

    // Sembol yoğunluğu %30 veya daha fazlaysa ve 5'ten fazla sembol varsa gürültüdür
    return symbolCount >= 5 && (symbolCount / total) >= 0.30;
  }
}
