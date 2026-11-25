import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Sorunlu veya interaktif alanın kategorisi
enum SnippetType {
  /// Bozuk CMap / anlamsız glif dizisine sahip Arapça hat veya ibare
  arabicCalligraphy,

  /// Tablo ve matris verileri
  table,

  /// Vektörel şema, grafik ve çizimler
  diagram,

  /// Sayfa altındaki özel dipnot ve şerhler
  footnote,

  /// Standart dışı kaligrafik başlık
  calligraphyTitle,

  /// Diğer görsel kesitler
  unresolvedSnippet,
}

/// Sayfa içi dipnot referans çapası
@immutable
class FootnoteAnchor {
  final String key;
  final int indexInText;
  final String? content;

  const FootnoteAnchor({
    required this.key,
    required this.indexInText,
    this.content,
  });
}

/// Akıllı Reflow sayfa içeriğini temsil eden hiyerarşik mühürlü sınıf (Sealed Class)
sealed class ContentBlock {
  const ContentBlock();
}

/// Kusursuzlaştırılmış, temiz Türkçe/İngilizce gövde metni veya başlık bloğu
final class TextBlock extends ContentBlock {
  final String text;
  final bool isHeading;
  final bool isArabic;
  final List<FootnoteAnchor> footnoteAnchors;

  const TextBlock({
    required this.text,
    this.isHeading = false,
    this.isArabic = false,
    this.footnoteAnchors = const [],
  });

  TextBlock copyWith({
    String? text,
    bool? isHeading,
    bool? isArabic,
    List<FootnoteAnchor>? footnoteAnchors,
  }) {
    return TextBlock(
      text: text ?? this.text,
      isHeading: isHeading ?? this.isHeading,
      isArabic: isArabic ?? this.isArabic,
      footnoteAnchors: footnoteAnchors ?? this.footnoteAnchors,
    );
  }
}

/// Sorunlu alanların (Arapça hat, tablo, şema, dipnot) 300 DPI kırpılmış orijinal net görseli
/// ve metin arasına gömülen interaktif rozeti
final class InteractiveSnippetBlock extends ContentBlock {
  final SnippetType type;
  final String title;
  final String? subtitle;
  final String croppedImagePath;
  final Uint8List? rawBytes;
  final Rect? boundingBox;
  final String? fallbackText;

  const InteractiveSnippetBlock({
    required this.type,
    required this.title,
    this.subtitle,
    required this.croppedImagePath,
    this.rawBytes,
    this.boundingBox,
    this.fallbackText,
  });

  String get badgeLabel {
    switch (type) {
      case SnippetType.arabicCalligraphy:
        return '📜 Orijinal İbare';
      case SnippetType.table:
        return '📊 Tablo';
      case SnippetType.diagram:
        return '📐 Şema / Vektör';
      case SnippetType.footnote:
        return '📝 Dipnot İncele';
      case SnippetType.calligraphyTitle:
        return '🖋️ Kaligrafik Başlık';
      case SnippetType.unresolvedSnippet:
        return '🔍 Orijinal Kesit';
    }
  }

  IconData get badgeIcon {
    switch (type) {
      case SnippetType.arabicCalligraphy:
        return Icons.draw_rounded;
      case SnippetType.table:
        return Icons.table_chart_rounded;
      case SnippetType.diagram:
        return Icons.schema_rounded;
      case SnippetType.footnote:
        return Icons.bookmark_added_rounded;
      case SnippetType.calligraphyTitle:
        return Icons.auto_stories_rounded;
      case SnippetType.unresolvedSnippet:
        return Icons.crop_original_rounded;
    }
  }
}

/// Sayfa başında doğrudan görsel olarak konumlandırılacak kırpılmış yüksek çözünürlüklü başlık
final class CalligraphyHeaderBlock extends ContentBlock {
  final String title;
  final String croppedImagePath;
  final Uint8List? rawBytes;
  final Rect? boundingBox;

  const CalligraphyHeaderBlock({
    required this.title,
    required this.croppedImagePath,
    this.rawBytes,
    this.boundingBox,
  });
}

/// Düşük güvenli, Arapça veya tablo içeren bölgeyi aktif tema rengine boyanan
/// şeffaf mürekkep alfa-maskesi olarak metin akışına gömer (beyaz kutusuz).
final class OpticalInkBlock extends ContentBlock {
  final String title;
  final String alphaMaskPath;
  final Uint8List? rawAlphaMaskBytes;
  final Rect cropRect;
  final bool isArabic;
  final String? fallbackText;

  const OpticalInkBlock({
    required this.title,
    required this.alphaMaskPath,
    this.rawAlphaMaskBytes,
    required this.cropRect,
    this.isArabic = false,
    this.fallbackText,
  });
}
