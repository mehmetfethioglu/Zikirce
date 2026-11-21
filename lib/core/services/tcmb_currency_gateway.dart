import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../features/pdks/domain/pre_accounting_advanced_contracts.dart';

class _TcmbCacheEntry {
  final List<CurrencyRateQuote> rates;
  final DateTime fetchedAt;

  const _TcmbCacheEntry({
    required this.rates,
    required this.fetchedAt,
  });
}

/// TCMB günlük döviz kurları ağ geçidi (`today.xml`).
/// 4 sn bağlantı/okuma zaman aşımı, 15 dk TTL ve en fazla 8 girdili önbellek uygular.
class TcmbCurrencyGateway implements CurrencyRateGateway {
  static const String tcmbTodayUrl = 'https://www.tcmb.gov.tr/kurlar/today.xml';
  static const Duration defaultTimeout = Duration(seconds: 4);
  static const Duration cacheTtl = Duration(minutes: 15);
  static const int maxCacheEntries = 8;

  static const Map<String, String> _supportedCurrencies = <String, String>{
    'USD': 'ABD Doları',
    'EUR': 'Euro',
    'GBP': 'İngiliz Sterlini',
  };

  static const List<CurrencyRateQuote> _deterministicFallbackRates =
      <CurrencyRateQuote>[
    CurrencyRateQuote(
      code: 'USD',
      label: 'ABD Doları',
      buyingTl: 34.4200,
      sellingTl: 34.4900,
      updatedAtIso: '2026-11-13T09:00:00.000',
      isFallback: true,
    ),
    CurrencyRateQuote(
      code: 'EUR',
      label: 'Euro',
      buyingTl: 36.8500,
      sellingTl: 36.9300,
      updatedAtIso: '2026-11-13T09:00:00.000',
      isFallback: true,
    ),
    CurrencyRateQuote(
      code: 'GBP',
      label: 'İngiliz Sterlini',
      buyingTl: 43.9200,
      sellingTl: 44.1500,
      updatedAtIso: '2026-11-13T09:00:00.000',
      isFallback: true,
    ),
  ];

  static final RegExp _currencyBlockRegex = RegExp(
    r'<Currency\b([^>]*)>([\s\S]*?)<\/Currency>',
    caseSensitive: false,
  );

  static final RegExp _currencyCodeAttrRegex = RegExp(
    r'''(?:CurrencyCode|Kod)\s*=\s*["']([A-Za-z]{3})["']''',
    caseSensitive: false,
  );

  final Dio _dio;
  final bool _ownsDio;
  final DateTime Function() _nowProvider;
  final String _endpointUrl;
  final Map<String, _TcmbCacheEntry> _cache = <String, _TcmbCacheEntry>{};

  TcmbCurrencyGateway({
    Dio? dio,
    DateTime Function()? nowProvider,
    String endpointUrl = tcmbTodayUrl,
  })  : _ownsDio = dio == null,
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: defaultTimeout,
                receiveTimeout: defaultTimeout,
                sendTimeout: defaultTimeout,
                responseType: ResponseType.plain,
                headers: const <String, dynamic>{
                  'Accept': 'application/xml, text/xml, */*',
                },
              ),
            ),
        _nowProvider = nowProvider ?? DateTime.now,
        _endpointUrl = endpointUrl;

  int get cacheEntryCount => _cache.length;

  void clearCache() => _cache.clear();

  /// Kaynakların deterministik kapatılması.
  void close() {
    if (_ownsDio) {
      _dio.close();
    }
    _cache.clear();
  }

  @override
  List<CurrencyRateQuote> fallbackRates() => _deterministicFallbackRates;

  @override
  Future<List<CurrencyRateQuote>> fetchRates({
    bool forceRefresh = false,
  }) async {
    final now = _nowProvider();
    _evictExpiredEntries(now);

    if (!forceRefresh) {
      final cached = _cache[_endpointUrl];
      if (cached != null) {
        _touchCacheEntry(_endpointUrl, cached);
        return cached.rates;
      }
    }

    try {
      final response = await _dio.get<String>(
        _endpointUrl,
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: defaultTimeout,
        ),
      );

      final statusCode = response.statusCode ?? 0;
      final xmlBody = response.data ?? '';
      if (statusCode < 200 || statusCode >= 300 || xmlBody.trim().isEmpty) {
        debugPrint(
          'TcmbCurrencyGateway: Geçersiz HTTP yanıtı ($statusCode), fallback kurlar dönülüyor.',
        );
        return fallbackRates();
      }

      final parsed = parseTcmbXml(xmlBody, now: now);
      if (parsed.isEmpty) {
        debugPrint(
          'TcmbCurrencyGateway: TCMB XML yanıtında USD/EUR/GBP bulunamadı, fallback kurlar dönülüyor.',
        );
        return fallbackRates();
      }

      _putCacheEntry(_endpointUrl, parsed, now);
      return parsed;
    } on DioException catch (e) {
      debugPrint(
        'TcmbCurrencyGateway: TCMB ağ hatası (${e.type.name}): ${e.message}',
      );
      return fallbackRates();
    } catch (e, st) {
      debugPrint(
        'TcmbCurrencyGateway: Beklenmeyen kur güncelleme hatası: $e\n$st',
      );
      return fallbackRates();
    }
  }

  /// Saf TCMB XML ayrıştırıcı (USD, EUR, GBP).
  /// Önce `BanknoteBuying`/`BanknoteSelling` okur; boş veya <= 0 ise `ForexBuying`/`ForexSelling` kullanır.
  static List<CurrencyRateQuote> parseTcmbXml(
    String xml, {
    DateTime? now,
  }) {
    if (xml.trim().isEmpty) {
      return const <CurrencyRateQuote>[];
    }

    final updatedAtIso = (now ?? DateTime.now()).toIso8601String();
    final parsedByCode = <String, CurrencyRateQuote>{};

    for (final match in _currencyBlockRegex.allMatches(xml)) {
      final attrs = match.group(1) ?? '';
      final body = match.group(2) ?? '';
      final codeMatch = _currencyCodeAttrRegex.firstMatch(attrs);
      if (codeMatch == null) continue;

      final code = (codeMatch.group(1) ?? '').toUpperCase();
      final label = _supportedCurrencies[code];
      if (label == null) continue;

      final unit = _parsePositiveDouble(_extractXmlTag(body, 'Unit')) ?? 1.0;
      final banknoteBuying =
          _parsePositiveDouble(_extractXmlTag(body, 'BanknoteBuying'));
      final banknoteSelling =
          _parsePositiveDouble(_extractXmlTag(body, 'BanknoteSelling'));
      final forexBuying =
          _parsePositiveDouble(_extractXmlTag(body, 'ForexBuying'));
      final forexSelling =
          _parsePositiveDouble(_extractXmlTag(body, 'ForexSelling'));

      final rawBuying = banknoteBuying ?? forexBuying;
      final rawSelling = banknoteSelling ?? forexSelling;
      if (rawBuying == null || rawSelling == null) continue;

      final buyingTl = double.parse((rawBuying / unit).toStringAsFixed(4));
      final sellingTl = double.parse((rawSelling / unit).toStringAsFixed(4));

      parsedByCode[code] = CurrencyRateQuote(
        code: code,
        label: label,
        buyingTl: buyingTl,
        sellingTl: sellingTl,
        updatedAtIso: updatedAtIso,
        isFallback: false,
      );
    }

    if (parsedByCode.isEmpty) {
      return const <CurrencyRateQuote>[];
    }

    final ordered = <CurrencyRateQuote>[
      for (final code in _supportedCurrencies.keys)
        if (parsedByCode.containsKey(code)) parsedByCode[code]!,
    ];
    return List<CurrencyRateQuote>.unmodifiable(ordered);
  }

  static String _extractXmlTag(String body, String tagName) {
    final tagRegex = RegExp(
      '<$tagName\\b[^>]*>([\\s\\S]*?)<\\/$tagName>',
      caseSensitive: false,
    );
    final match = tagRegex.firstMatch(body);
    return match?.group(1)?.trim() ?? '';
  }

  static double? _parsePositiveDouble(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    final parsed = double.tryParse(normalized);
    if (parsed == null || parsed.isNaN || parsed.isInfinite || parsed <= 0.0) {
      return null;
    }
    return parsed;
  }

  void _evictExpiredEntries(DateTime now) {
    final expiredKeys = <String>[];
    for (final entry in _cache.entries) {
      final age = now.difference(entry.value.fetchedAt);
      if (age.isNegative || age >= cacheTtl) {
        expiredKeys.add(entry.key);
      }
    }
    for (final key in expiredKeys) {
      _cache.remove(key);
    }
  }

  void _touchCacheEntry(String key, _TcmbCacheEntry entry) {
    _cache.remove(key);
    _cache[key] = entry;
  }

  void _putCacheEntry(
    String key,
    List<CurrencyRateQuote> rates,
    DateTime fetchedAt,
  ) {
    _cache.remove(key);
    while (_cache.length >= maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = _TcmbCacheEntry(
      rates: List<CurrencyRateQuote>.unmodifiable(rates),
      fetchedAt: fetchedAt,
    );
  }
}
