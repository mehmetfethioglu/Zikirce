import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import '../../ocr/domain/cloud_vision_ocr_service.dart';
import 'kiler_models.dart';

class ReceiptParsedItem {
  final String rawLine;
  final QuickIngredientTemplate template;
  final bool selected;

  const ReceiptParsedItem({
    required this.rawLine,
    required this.template,
    this.selected = true,
  });

  ReceiptParsedItem copyWith({bool? selected}) {
    return ReceiptParsedItem(
      rawLine: rawLine,
      template: template,
      selected: selected ?? this.selected,
    );
  }
}

class ReceiptOcrService {
  static final List<String> _ignoredReceiptKeywords = [
    'toplam',
    'topkdv',
    'kdv',
    'nakit',
    'kredi',
    'banka',
    'kart',
    'fis no',
    'tarih',
    'saat',
    'mersis',
    'vergi',
    'v.d.',
    'tesekkur',
    'iyi gunler',
    'kasiyer',
    'magaza',
    'sube',
    'poset',
    'alisveris',
    'indirim',
    'ara toplam',
  ];

  /// Captures or selects a market receipt photo and extracts food items.
  /// Tries cost-efficient Gemini 2.5 Flash-Lite via Worker first, then falls back to ML Kit.
  static Future<List<ReceiptParsedItem>> scanReceiptFromSource(
    ImageSource source,
  ) async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: source,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 80,
    );

    if (photo == null) return const [];

    try {
      final Uint8List bytes = await photo.readAsBytes();
      final cloudItems =
          await CloudVisionOcrService.instance.analyzeReceiptImageBytes(bytes);
      if (cloudItems != null && cloudItems.isNotEmpty) {
        return mapCloudItems(cloudItems);
      }
    } catch (e) {
      debugPrint('ReceiptOcrService cloud fallback note: $e');
    }

    final TextRecognizer recognizer = TextRecognizer(
      script: TextRecognitionScript.latin,
    );

    try {
      final inputImage = InputImage.fromFilePath(photo.path);
      final RecognizedText recognized = await recognizer.processImage(inputImage);
      return parseReceiptText(recognized.text);
    } catch (e) {
      debugPrint('ReceiptOcrService.scanReceiptFromSource error: $e');
      rethrow;
    } finally {
      await recognizer.close();
    }
  }

  /// Maps structured items returned by Gemini 2.5 Flash-Lite into deduplicated [ReceiptParsedItem]s.
  static List<ReceiptParsedItem> mapCloudItems(List<CloudReceiptItem> cloudItems) {
    final Map<String, ReceiptParsedItem> uniqueByTag = {};

    for (final item in cloudItems) {
      final cleanName = item.name.trim();
      if (cleanName.length < 2) continue;

      final resolved = IngredientNormalizer.resolveMetadata(cleanName);
      final StorageZone effectiveZone = item.storageZoneCode.trim().isNotEmpty
          ? StorageZone.fromDb(item.storageZoneCode.trim().toUpperCase())
          : resolved.defaultZone;
      final String effectiveUnit = item.unitLabel.trim().isNotEmpty
          ? item.unitLabel.trim()
          : resolved.defaultUnit;

      final template = QuickIngredientTemplate(
        tag: resolved.tag,
        name: cleanName,
        emoji: resolved.emoji,
        category: resolved.category,
        defaultZone: effectiveZone,
        defaultShelfDays: resolved.defaultShelfDays,
        defaultUnit: effectiveUnit,
        defaultHealthScore: resolved.defaultHealthScore,
        keywords: resolved.keywords,
      );

      uniqueByTag.putIfAbsent(
        resolved.tag,
        () => ReceiptParsedItem(
          rawLine: item.rawLine.isNotEmpty ? item.rawLine : cleanName,
          template: template,
          selected: true,
        ),
      );
    }

    return uniqueByTag.values.toList();
  }

  /// Parses raw OCR text from a Turkish grocery receipt into matched food templates.
  static List<ReceiptParsedItem> parseReceiptText(String rawText) {
    if (rawText.trim().isEmpty) return const [];

    final lines = rawText.split(RegExp(r'\r?\n'));
    final Map<String, ReceiptParsedItem> uniqueByTag = {};

    for (final rawLine in lines) {
      final cleaned = _cleanReceiptLine(rawLine);
      if (cleaned.length < 3) continue;
      if (_isIgnoredReceiptLine(cleaned)) continue;

      final resolved = IngredientNormalizer.resolveMetadata(cleaned);
      // Include all known catalog matches or valid food lines >= 4 chars
      final isKnownTemplate = QuickIngredientCatalog.findByTag(resolved.tag) != null;
      if (isKnownTemplate || _looksLikeProductName(cleaned)) {
        uniqueByTag.putIfAbsent(
          resolved.tag,
          () => ReceiptParsedItem(
            rawLine: cleaned,
            template: resolved,
            selected: true,
          ),
        );
      }
    }

    return uniqueByTag.values.toList();
  }

  static String _cleanReceiptLine(String line) {
    // Strip prices (*125,90), tax rates (%01, %10), weights (1.250 KG X)
    String s = line
        .replaceAll(RegExp(r'\*[0-9]+[.,][0-9]{2}'), '')
        .replaceAll(RegExp(r'%[0-9]{1,2}'), '')
        .replaceAll(RegExp(r'[0-9]+[.,][0-9]{2}\s*(TL|₺)?', caseSensitive: false), '')
        .replaceAll(RegExp(r'[0-9]+\s*(ADET|AD|KG|GR|LT|PK)', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^a-zA-ZçğıöşüÇĞİÖŞÜ\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return s;
  }

  static bool _isIgnoredReceiptLine(String line) {
    final lower = line
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');

    for (final kw in _ignoredReceiptKeywords) {
      if (lower.contains(kw)) return true;
    }
    return false;
  }

  static bool _looksLikeProductName(String cleaned) {
    final words = cleaned.split(' ').where((w) => w.length >= 3).toList();
    return words.isNotEmpty && cleaned.length >= 4 && cleaned.length <= 36;
  }
}
