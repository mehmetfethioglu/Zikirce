import 'dart:convert';
import 'package:flutter/services.dart';

class QuranAyatModel {
  final int id;
  final int sureId;
  final int ayetId;
  final String ayetNumber;
  final String ayetText;
  final int page;
  final String? recitation;
  final SureMeta? sure;

  QuranAyatModel({
    required this.id,
    required this.sureId,
    required this.ayetId,
    required this.ayetNumber,
    required this.ayetText,
    this.page = 1,
    this.recitation,
    this.sure,
  });

  factory QuranAyatModel.fromJson(Map<String, dynamic> json) {
    String rawText = json['AyetText']?.toString() ?? '';
    // Normalize typographical artifacts and non-breaking spaces
    rawText = rawText.replaceAll('D', 'ْد').replaceAll('\u00A0', ' ').replaceAll('\u202F', ' ');

    return QuranAyatModel(
      id: json['Id'] as int? ?? 0,
      sureId: json['SureId'] as int? ?? 0,
      ayetId: json['AyetId'] as int? ?? 0,
      ayetNumber: json['AyetNumber']?.toString() ?? '',
      ayetText: rawText,
      page: json['Page'] as int? ?? 1,
      recitation: json['Recitation']?.toString(),
      sure: json['Sure'] != null ? SureMeta.fromJson(json['Sure']) : null,
    );
  }
}

class MealAyatModel {
  final int id;
  final int sureId;
  final int ayetId;
  final String ayetNumber;
  final String ayetText;
  final int page;
  final SureMeta? sure;

  MealAyatModel({
    required this.id,
    required this.sureId,
    required this.ayetId,
    required this.ayetNumber,
    required this.ayetText,
    this.page = 1,
    this.sure,
  });

  factory MealAyatModel.fromJson(Map<String, dynamic> json) {
    return MealAyatModel(
      id: json['Id'] as int? ?? 0,
      sureId: json['SureId'] as int? ?? 0,
      ayetId: json['AyetId'] as int? ?? 0,
      ayetNumber: json['AyetNumber']?.toString() ?? '',
      ayetText: json['AyetText']?.toString() ?? '',
      page: json['Page'] as int? ?? 1,
      sure: json['Sure'] != null ? SureMeta.fromJson(json['Sure']) : null,
    );
  }
}

class SureMeta {
  final int sureId;
  final String sureNameTurkish;
  final String sureNameArabic;
  final String? mealInfo;
  final bool besmeleVisible;
  final int ayetCount;
  final int cuz;
  final int firstPage;

  SureMeta({
    required this.sureId,
    required this.sureNameTurkish,
    required this.sureNameArabic,
    this.mealInfo,
    this.besmeleVisible = false,
    this.ayetCount = 0,
    this.cuz = 1,
    this.firstPage = 1,
  });

  factory SureMeta.fromJson(Map<String, dynamic> json) {
    return SureMeta(
      sureId: json['SureId'] as int? ?? 0,
      sureNameTurkish: json['SureNameTurkish']?.toString() ?? '',
      sureNameArabic: json['SureNameArabic']?.toString() ?? '',
      mealInfo: json['MealInfo']?.toString(),
      besmeleVisible: json['BesmeleVisible'] as bool? ?? false,
      ayetCount: json['AyetCount'] as int? ?? 0,
      cuz: json['Cuz'] as int? ?? 1,
      firstPage: json['FirstPage'] as int? ?? 1,
    );
  }
}

class QuranPageData {
  final int pageNo;
  final int cuzNo;
  final String arCuzNo;
  final String arPageNo;
  final String mealSureLabel;
  final String quranSureLabel;
  final List<QuranAyatModel> quranAyats;
  final List<MealAyatModel> mealAyats;

  QuranPageData({
    required this.pageNo,
    required this.cuzNo,
    required this.arCuzNo,
    required this.arPageNo,
    required this.mealSureLabel,
    required this.quranSureLabel,
    required this.quranAyats,
    required this.mealAyats,
  });

  factory QuranPageData.fromJson(Map<String, dynamic> json) {
    return QuranPageData(
      pageNo: json['PageNo'] as int? ?? 1,
      cuzNo: json['CuzNo'] as int? ?? 1,
      arCuzNo: json['ArCuzNo']?.toString() ?? '',
      arPageNo: json['ArPageNo']?.toString() ?? '',
      mealSureLabel: json['MealSureLabel']?.toString() ?? '',
      quranSureLabel: json['QuranSureLabel']?.toString() ?? '',
      quranAyats: (json['QuranAyats'] as List<dynamic>?)
              ?.map((e) => QuranAyatModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      mealAyats: (json['MealAyats'] as List<dynamic>?)
              ?.map((e) => MealAyatModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class QuranPageRepository {
  static final Map<int, QuranPageData> _pageCache = {};

  /// Loads and parses page data from local assets for any of the 605 pages (1-indexed).
  static Future<QuranPageData> getPage(int pageNumber) async {
    final clamped = pageNumber.clamp(1, 605);
    if (_pageCache.containsKey(clamped)) {
      return _pageCache[clamped]!;
    }

    final assetPath = 'assets/raw/Diyanet_Sayfa_Metinleri_JSON/$clamped.json';
    final jsonStr = await rootBundle.loadString(assetPath);
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    final pageData = QuranPageData.fromJson(map);

    _pageCache[clamped] = pageData;
    return pageData;
  }

  /// Preloads adjacent pages for butter-smooth 120 FPS swiping
  static Future<void> preloadAround(int pageNumber) async {
    if (pageNumber > 1) getPage(pageNumber - 1);
    if (pageNumber < 605) getPage(pageNumber + 1);
  }
}
