import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';

class DetectedAdditive {
  final String code;
  final String name;
  final String riskLevel; // LOW, MODERATE, HIGH, TOXIC
  final String category;
  final String healthHazards;

  DetectedAdditive({
    required this.code,
    required this.name,
    required this.riskLevel,
    required this.category,
    required this.healthHazards,
  });
}

class IngredientParseResult {
  final String rawText;
  final List<DetectedAdditive> additives;
  final List<String> highlightedWords;
  final double parsingTimeMs;

  IngredientParseResult({
    required this.rawText,
    required this.additives,
    required this.highlightedWords,
    required this.parsingTimeMs,
  });
}

class IngredientParser {
  // Regex pattern matching E-numbers e.g. E102, E 211, E-621, e951
  static final RegExp _eNumberRegex = RegExp(
    r'\b[Ee][\s\-\.]?(\d{3,4}[a-zA-Z]?)\b',
    caseSensitive: false,
  );

  /// Parses raw ingredient text against local SQLite E-number database.
  /// Execution time strictly targeted <50ms.
  static Future<IngredientParseResult> parseIngredients(String rawText) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    final Database db = await DatabaseHelper().database;
    final String lowerRaw = rawText.toLowerCase();

    final Iterable<Match> matches = _eNumberRegex.allMatches(rawText);
    final List<DetectedAdditive> detectedList = [];
    final List<String> highlights = [];
    final Set<String> processedCodes = {};

    // 1. Match E-numbers e.g. E102, E211, E-621
    for (final match in matches) {
      final String matchedStr = match.group(0) ?? '';
      final String codeDigits = match.group(1) ?? '';
      final String fullCode = 'E$codeDigits'.toUpperCase();

      if (processedCodes.contains(fullCode)) continue;
      processedCodes.add(fullCode);

      final List<Map<String, dynamic>> results = await db.query(
        'e_numbers',
        where: 'code = ?',
        whereArgs: [fullCode],
      );

      if (results.isNotEmpty) {
        final row = results.first;
        detectedList.add(DetectedAdditive(
          code: row['code'] as String,
          name: row['name'] as String,
          riskLevel: row['risk_level'] as String,
          category: row['category'] as String? ?? 'Katkı Maddesi',
          healthHazards: row['health_hazards'] as String? ?? '',
        ));
        highlights.add(matchedStr);
      }
    }

    // 2. Match additives by name from local e_numbers database
    try {
      final List<Map<String, dynamic>> allENumbers = await db.query('e_numbers');
      for (final row in allENumbers) {
        final String code = row['code'] as String;
        if (processedCodes.contains(code)) continue;

        final String name = (row['name'] as String).toLowerCase();
        final List<String> nameParts = name.split(RegExp(r'[\(\s,/-]+'));
        bool matchFound = false;
        for (final part in nameParts) {
          final cleanPart = part.replaceAll(RegExp(r'[^a-zA-ZçğıöşüÇĞİÖŞÜ0-9]'), '').trim();
          if (cleanPart.length >= 5 && lowerRaw.contains(cleanPart.toLowerCase())) {
            matchFound = true;
            break;
          }
        }

        if (matchFound) {
          processedCodes.add(code);
          detectedList.add(DetectedAdditive(
            code: code,
            name: row['name'] as String,
            riskLevel: row['risk_level'] as String,
            category: row['category'] as String? ?? 'Katkı Maddesi',
            healthHazards: row['health_hazards'] as String? ?? '',
          ));
          highlights.add(row['name'] as String);
        }
      }
    } catch (e) {
      debugPrint('IngredientParser name lookup error: $e');
    }

    stopwatch.stop();
    return IngredientParseResult(
      rawText: rawText,
      additives: detectedList,
      highlightedWords: highlights,
      parsingTimeMs: stopwatch.elapsedMicroseconds / 1000.0,
    );
  }

  /// Purges volatile memory buffers immediately post-OCR to prevent RAM leaks (NFR-1.4 compliance).
  static void purgeRamBuffer(List<int>? imageBufferBytes) {
    if (imageBufferBytes != null) {
      imageBufferBytes.clear();
    }
  }
}
