import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MealSourceInfo {
  final String id;
  final String title;
  final String shortTitle;
  final String author;
  final String description;
  final String editionSlug;
  final String sizeLabel;
  final bool isBuiltIn;
  final bool isTransliteration;

  const MealSourceInfo({
    required this.id,
    required this.title,
    required this.shortTitle,
    required this.author,
    required this.description,
    required this.editionSlug,
    required this.sizeLabel,
    this.isBuiltIn = false,
    this.isTransliteration = false,
  });
}

class MealComparisonEntry {
  final MealSourceInfo source;
  final String text;

  const MealComparisonEntry({
    required this.source,
    required this.text,
  });
}

class MealService {
  static final MealService _instance = MealService._internal();
  factory MealService() => _instance;
  MealService._internal();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  static const List<MealSourceInfo> availableSources = [
    MealSourceInfo(
      id: 'diyanet_vakfi_offline',
      title: 'Diyanet İşleri Başkanlığı Meâli',
      shortTitle: 'Diyanet İşleri',
      author: 'Diyanet İşleri Başkanlığı (Yerleşik)',
      description: 'Uygulama içinde yerleşik gelen resmî Kur\'ân-ı Kerîm meâli.',
      editionSlug: 'builtin',
      sizeLabel: 'Yerleşik',
      isBuiltIn: true,
    ),
    MealSourceInfo(
      id: 'elmalili_sade',
      title: 'Elmalılı Hamdi Yazır (Sadeleştirilmiş)',
      shortTitle: 'Elmalılı (Sade)',
      author: 'Elmalılı M. Hamdi Yazır (Kamu Malı Klasik)',
      description: 'Hak Dini Kur\'an Dili meâlinin günümüz Türkçesine sadeleştirilmiş akıcı metni.',
      editionSlug: 'tur-elmallsadelesti',
      sizeLabel: '0.4 MB',
    ),
    MealSourceInfo(
      id: 'elmalili_orijinal',
      title: 'Elmalılı Hamdi Yazır (Orijinal Metin)',
      shortTitle: 'Elmalılı (Orijinal)',
      author: 'Elmalılı M. Hamdi Yazır (1878–1942)',
      description: 'Cumhuriyet dönemi tefsir ve meâl klasiğinin özgün edebi üslubu.',
      editionSlug: 'tur-elmalilihamdiya',
      sizeLabel: '0.4 MB',
    ),
    MealSourceInfo(
      id: 'cantay',
      title: 'Hasan Basri Çantay Meâli',
      shortTitle: 'H. Basri Çantay',
      author: 'Hasan Basri Çantay (1887–1964)',
      description: 'Kur\'ân-ı Hakîm ve Meâl-i Kerîm; klasik ilmî sadakati yüksek meâl çalışması.',
      editionSlug: 'tur-hasanbasricanta',
      sizeLabel: '0.5 MB',
    ),
    MealSourceInfo(
      id: 'diyanet_vakfi',
      title: 'Türkiye Diyanet Vakfı Meâli',
      shortTitle: 'Diyanet Vakfı',
      author: 'TDV İslâm Araştırmaları Heyeti',
      description: 'Akademik heyet tarafından hazırlanan açık ve anlaşılır Türkçe meâl.',
      editionSlug: 'tur-diyanetvakfi',
      sizeLabel: '0.4 MB',
    ),
    MealSourceInfo(
      id: 'ali_fikri_yavuz',
      title: 'Ali Fikri Yavuz Meâli',
      shortTitle: 'Ali Fikri Yavuz',
      author: 'Ali Fikri Yavuz (1902–1981)',
      description: 'Klasik fıkıh ve tefsir geleneğine bağlı veciz Kur\'ân-ı Kerîm meâli.',
      editionSlug: 'tur-alifikriyavuz',
      sizeLabel: '0.5 MB',
    ),
    MealSourceInfo(
      id: 'suat_yildirim',
      title: 'Suat Yıldırım Meâli',
      shortTitle: 'Suat Yıldırım',
      author: 'Prof. Dr. Suat Yıldırım',
      description: 'Çağdaş Türkçe akıcılığıyla hazırlanmış açıklamalı meâl metni.',
      editionSlug: 'tur-suatyildirim',
      sizeLabel: '0.5 MB',
    ),
  ];

  static const MealSourceInfo transliterationSource = MealSourceInfo(
    id: 'transliteration',
    title: 'Türkçe Okunuş (Latin Transkripsiyon)',
    shortTitle: 'Türkçe Okunuş',
    author: 'Latin Harfli Telaffuz Rehberi',
    description: 'Âyetlerin Latin harfleriyle yaklaşık okunuşunu satır altında gösterir.',
    editionSlug: 'tur-latinalphabet',
    sizeLabel: '0.4 MB',
    isTransliteration: true,
  );

  final Map<String, Map<String, String>> _memoryCache = {};
  final Set<String> _downloadingIds = {};

  static MealSourceInfo getSourceInfo(String id) {
    if (id == transliterationSource.id) return transliterationSource;
    return availableSources.firstWhere(
      (s) => s.id == id,
      orElse: () => availableSources.first,
    );
  }

  Future<String> _getMealsDirPath() async {
    final docDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docDir.path, 'meals'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  Future<File> _getSourceFile(String sourceId) async {
    final dir = await _getMealsDirPath();
    return File(p.join(dir, '$sourceId.json'));
  }

  Future<bool> isDownloaded(String sourceId) async {
    final info = getSourceInfo(sourceId);
    if (info.isBuiltIn) return true;
    if (_memoryCache.containsKey(sourceId)) return true;
    final file = await _getSourceFile(sourceId);
    return file.existsSync() && file.lengthSync() > 1024;
  }

  Future<Map<String, String>?> _ensureLoaded(String sourceId) async {
    final info = getSourceInfo(sourceId);
    if (info.isBuiltIn) return null;
    if (_memoryCache.containsKey(sourceId)) {
      return _memoryCache[sourceId];
    }

    final file = await _getSourceFile(sourceId);
    if (await file.exists() && await file.length() > 1024) {
      try {
        final raw = await file.readAsString();
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final map = decoded.map((k, v) => MapEntry(k, v.toString()));
        _memoryCache[sourceId] = map;
        return map;
      } catch (e) {
        debugPrint('[MealService] Failed to read cached meal $sourceId: $e');
      }
    }

    // Auto-download lightweight meal JSON (~450 KB) on demand
    final ok = await downloadSource(sourceId);
    if (ok) {
      return _memoryCache[sourceId];
    }
    return null;
  }

  Future<bool> downloadSource(
    String sourceId, {
    void Function(double progress)? onProgress,
  }) async {
    final info = getSourceInfo(sourceId);
    if (info.isBuiltIn) return true;
    if (_downloadingIds.contains(sourceId)) return false;
    _downloadingIds.add(sourceId);

    try {
      final urls = [
        'https://cdn.jsdelivr.net/gh/fawazahmed0/quran-api@1/editions/${info.editionSlug}.min.json',
        'https://raw.githubusercontent.com/fawazahmed0/quran-api/1/editions/${info.editionSlug}.min.json',
      ];

      Map<String, dynamic>? payload;
      for (final url in urls) {
        try {
          final response = await _dio.get<String>(
            url,
            options: Options(responseType: ResponseType.plain),
            onReceiveProgress: (received, total) {
              if (onProgress != null && total > 0) {
                onProgress((received / total).clamp(0.0, 1.0));
              }
            },
          );
          if (response.statusCode == 200 && response.data != null) {
            payload = jsonDecode(response.data!) as Map<String, dynamic>;
            break;
          }
        } catch (_) {
          continue;
        }
      }

      if (payload == null || !payload.containsKey('quran')) {
        return false;
      }

      final quranList = payload['quran'] as List<dynamic>;
      final Map<String, String> verseMap = {};
      for (final item in quranList) {
        if (item is Map<String, dynamic>) {
          final ch = item['chapter'];
          final v = item['verse'];
          final txt = (item['text'] ?? '').toString().trim();
          if (ch != null && v != null && txt.isNotEmpty) {
            verseMap['$ch:$v'] = txt;
          }
        }
      }

      if (verseMap.isEmpty) return false;

      final file = await _getSourceFile(sourceId);
      await file.writeAsString(jsonEncode(verseMap), flush: true);
      _memoryCache[sourceId] = verseMap;
      onProgress?.call(1.0);
      return true;
    } catch (e) {
      debugPrint('[MealService] Download error for $sourceId: $e');
      return false;
    } finally {
      _downloadingIds.remove(sourceId);
    }
  }

  Future<void> deleteSource(String sourceId) async {
    final info = getSourceInfo(sourceId);
    if (info.isBuiltIn) return;
    _memoryCache.remove(sourceId);
    final file = await _getSourceFile(sourceId);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<String> getVerseMeal(
    int surahId,
    int verseNumber, {
    required String sourceId,
    String? fallbackDiyanetText,
  }) async {
    final info = getSourceInfo(sourceId);
    if (info.isBuiltIn) {
      return fallbackDiyanetText ?? '';
    }
    final map = await _ensureLoaded(sourceId);
    if (map == null) {
      return fallbackDiyanetText ?? '';
    }
    return map['$surahId:$verseNumber'] ?? fallbackDiyanetText ?? '';
  }

  Future<String?> getTransliteration(int surahId, int verseNumber) async {
    final map = await _ensureLoaded(transliterationSource.id);
    return map?['$surahId:$verseNumber'];
  }

  Future<List<MealComparisonEntry>> getComparativeMeals(
    int surahId,
    int verseNumber, {
    required List<String> sourceIds,
    String? defaultDiyanetText,
  }) async {
    final List<MealComparisonEntry> results = [];
    for (final id in sourceIds) {
      final info = getSourceInfo(id);
      if (info.isBuiltIn) {
        if (defaultDiyanetText != null && defaultDiyanetText.isNotEmpty) {
          results.add(MealComparisonEntry(source: info, text: defaultDiyanetText));
        }
        continue;
      }
      final map = await _ensureLoaded(id);
      final text = map?['$surahId:$verseNumber'];
      if (text != null && text.isNotEmpty) {
        results.add(MealComparisonEntry(source: info, text: text));
      }
    }
    return results;
  }
}

final mealServiceProvider = Provider<MealService>((ref) => MealService());

class ActiveMealSourceNotifier extends StateNotifier<String> {
  static const _prefKey = 'kuran_active_meal_source';

  ActiveMealSourceNotifier() : super('diyanet_vakfi_offline') {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null && saved.isNotEmpty) {
      state = saved;
    }
  }

  Future<void> setSource(String sourceId) async {
    state = sourceId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, sourceId);
    if (sourceId != 'diyanet_vakfi_offline') {
      await MealService().downloadSource(sourceId);
    }
  }
}

final activeMealSourceProvider =
    StateNotifierProvider<ActiveMealSourceNotifier, String>(
  (ref) => ActiveMealSourceNotifier(),
);

class ComparisonMealSourcesNotifier extends StateNotifier<List<String>> {
  static const _prefKey = 'kuran_comparison_meal_sources';

  ComparisonMealSourcesNotifier()
      : super(const ['diyanet_vakfi_offline', 'elmalili_sade', 'cantay']) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_prefKey);
    if (saved != null && saved.isNotEmpty) {
      state = saved;
    }
  }

  Future<void> toggleSource(String sourceId) async {
    final next = List<String>.from(state);
    if (next.contains(sourceId)) {
      if (next.length > 1) {
        next.remove(sourceId);
      }
    } else {
      next.add(sourceId);
      if (sourceId != 'diyanet_vakfi_offline') {
        MealService().downloadSource(sourceId);
      }
    }
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefKey, next);
  }
}

final comparisonMealSourcesProvider =
    StateNotifierProvider<ComparisonMealSourcesNotifier, List<String>>(
  (ref) => ComparisonMealSourcesNotifier(),
);

final isMealComparisonEnabledProvider = StateProvider<bool>((ref) => false);

class ShowTransliterationNotifier extends StateNotifier<bool> {
  static const _prefKey = 'kuran_show_transliteration';

  ShowTransliterationNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_prefKey) ?? false;
  }

  Future<void> toggle(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
    if (value) {
      await MealService().downloadSource(MealService.transliterationSource.id);
    }
  }
}

final showTransliterationProvider =
    StateNotifierProvider<ShowTransliterationNotifier, bool>(
  (ref) => ShowTransliterationNotifier(),
);

/// 'card' (Detaylı Âyet Kartları) veya 'book' (Akıcı Kitap Okuma Modu)
class MealLayoutStyleNotifier extends StateNotifier<String> {
  static const _prefKey = 'kuran_meal_layout_style';

  MealLayoutStyleNotifier() : super('card') {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_prefKey) ?? 'card';
  }

  Future<void> setStyle(String style) async {
    state = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, style);
  }
}

final mealLayoutStyleProvider =
    StateNotifierProvider<MealLayoutStyleNotifier, String>(
  (ref) => MealLayoutStyleNotifier(),
);

class KuranFontSettings {
  final double arabicFontSize;
  final double mealFontSize;
  final double lineHeight;

  const KuranFontSettings({
    this.arabicFontSize = 26.0,
    this.mealFontSize = 16.0,
    this.lineHeight = 1.65,
  });

  KuranFontSettings copyWith({
    double? arabicFontSize,
    double? mealFontSize,
    double? lineHeight,
  }) {
    return KuranFontSettings(
      arabicFontSize: arabicFontSize ?? this.arabicFontSize,
      mealFontSize: mealFontSize ?? this.mealFontSize,
      lineHeight: lineHeight ?? this.lineHeight,
    );
  }
}

class KuranFontSettingsNotifier extends StateNotifier<KuranFontSettings> {
  static const _arKey = 'kuran_arabic_font_size';
  static const _mealKey = 'kuran_meal_font_size';
  static const _lhKey = 'kuran_line_height';

  KuranFontSettingsNotifier() : super(const KuranFontSettings()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = KuranFontSettings(
      arabicFontSize: prefs.getDouble(_arKey) ?? 26.0,
      mealFontSize: prefs.getDouble(_mealKey) ?? 16.0,
      lineHeight: prefs.getDouble(_lhKey) ?? 1.65,
    );
  }

  Future<void> setArabicFontSize(double size) async {
    final clamped = size.clamp(20.0, 42.0);
    state = state.copyWith(arabicFontSize: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_arKey, clamped);
  }

  Future<void> setMealFontSize(double size) async {
    final clamped = size.clamp(13.0, 26.0);
    state = state.copyWith(mealFontSize: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_mealKey, clamped);
  }

  Future<void> setLineHeight(double lh) async {
    final clamped = lh.clamp(1.35, 2.1);
    state = state.copyWith(lineHeight: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_lhKey, clamped);
  }
}

final kuranFontSettingsProvider =
    StateNotifierProvider<KuranFontSettingsNotifier, KuranFontSettings>(
  (ref) => KuranFontSettingsNotifier(),
);
