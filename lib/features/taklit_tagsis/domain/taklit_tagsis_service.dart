import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';

class TaklitTagsisItem {
  final int? id;
  final String companyName;
  final String brandName;
  final String productName;
  final String reason;
  final String category;
  final DateTime announcedAt;

  TaklitTagsisItem({
    this.id,
    required this.companyName,
    required this.brandName,
    required this.productName,
    required this.reason,
    required this.category,
    required this.announcedAt,
  });

  factory TaklitTagsisItem.fromMap(Map<String, dynamic> map) {
    return TaklitTagsisItem(
      id: map['id'] as int?,
      companyName: map['company_name'] as String? ?? 'Bilinmeyen Firma',
      brandName: map['brand_name'] as String? ?? 'Bilinmeyen Marka',
      productName: map['product_name'] as String? ?? 'Ürün',
      reason: map['reason'] as String? ?? 'Uygunsuzluk tespiti',
      category: map['category'] as String? ?? 'Gıda',
      announcedAt: DateTime.fromMillisecondsSinceEpoch(
        map['announced_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  /// Cleaned reason without category prefix tags
  String get cleanReason {
    return reason.replaceAll(RegExp(r'^\[.*?\]\s*'), '').trim();
  }

  /// True if this item represents a severe health hazard
  bool get isHealthHazard {
    final lower = reason.toLowerCase();
    return lower.contains('sağlığı tehlikeye') ||
        lower.contains('tek tırnaklı') ||
        lower.contains('domuz') ||
        lower.contains('ilaç');
  }
}

class TaklitTagsisBrandGroup {
  final String brandName;
  final String companyName;
  final String primaryCategory;
  final bool hasHealthHazard;
  final List<String> uniqueReasons;
  final List<TaklitTagsisItem> products;
  final DateTime latestAnnouncedAt;

  TaklitTagsisBrandGroup({
    required this.brandName,
    required this.companyName,
    required this.primaryCategory,
    required this.hasHealthHazard,
    required this.uniqueReasons,
    required this.products,
    required this.latestAnnouncedAt,
  });

  /// Short summary of the primary detected adulteration
  String get primaryReasonSummary {
    if (uniqueReasons.isEmpty) return 'Mevzuata aykırı içerik';
    return uniqueReasons.first;
  }

  /// Total count of blacklisted products under this brand
  int get productCount => products.length;
}

class TaklitTagsisService {
  static const String _prefLastSyncKey = 'taklit_tagsis_last_sync_timestamp';

  /// Legal and commercial corporate suffix stopwords that should never trigger false brand matches.
  static const Set<String> _corporateStopwords = {
    'ltd', 'sti', 'sirketi', 'sirket', 'anonim', 'as', 'ticaret', 'tic',
    'sanayi', 'san', 'gida', 'ithalat', 'ihracat', 'pazarlama', 'paz',
    've', 'tarim', 'hayvancilik', 'insaat', 'petrol', 'imalat', 'turizm',
    'isletmeleri', 'isletme', 'subesi', 'sube', 'holding', 'grup', 'uretim',
    'urunleri', 'urun', 'turk', 'turkiye', 'merkez'
  };

  /// Normalizes Turkish characters and formats a string for robust matching.
  static String normalizeForSearch(String input) {
    return input
        .replaceAll('İ', 'i')
        .replaceAll('I', 'i')
        .replaceAll('ı', 'i')
        .toLowerCase()
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Evaluates whether a blacklisted item matches the scanned product and brand.
  /// Strictly prevents false positives caused by substring overlap (e.g. 'eti' matching 'şirketi' or 'tek tırnaklı eti').
  static bool isItemMatching(
    TaklitTagsisItem item, {
    required String productName,
    required String brandName,
  }) {
    final normBrand = normalizeForSearch(brandName);
    final normProduct = normalizeForSearch(productName);

    // Filter out generic placeholder brands
    final bool hasValidBrand = normBrand.isNotEmpty &&
        normBrand != 'dogrulanmamis marka' &&
        normBrand != 'bilinmeyen marka' &&
        normBrand != 'markasiz' &&
        normBrand != 'yok' &&
        normBrand != '-' &&
        normBrand.length >= 2;

    final normRowBrand = normalizeForSearch(item.brandName);
    final normRowCompany = normalizeForSearch(item.companyName);
    final normRowProduct = normalizeForSearch(item.productName);

    if (hasValidBrand) {
      final qbWords = normBrand.split(' ').where((w) => w.isNotEmpty).toList();

      // 1. Check against the item's official brand name
      final bool hasRowBrand = normRowBrand.isNotEmpty &&
          normRowBrand != 'bilinmeyen marka' &&
          normRowBrand != 'yok' &&
          normRowBrand != 'ticari unvan' &&
          normRowBrand != '-';

      if (hasRowBrand) {
        // 1a. Exact brand match
        if (normBrand == normRowBrand) return true;

        final rbWords = normRowBrand.split(' ').where((w) => w.isNotEmpty).toList();

        // 1b. Single-word brand (e.g. "Ergün"): must match a complete standalone token in row brand
        if (qbWords.length == 1) {
          final word = qbWords.first;
          if (!_corporateStopwords.contains(word) && rbWords.contains(word)) {
            return true;
          }
        } else {
          // 1c. Multi-word brand: all query words must exist in row brand words
          if (qbWords.every((w) => rbWords.contains(w))) {
            return true;
          }
        }

        // 1d. Row brand fully contained in query brand (e.g. query: "Ergün Sucukları Dana Sucuk", row: "Ergün Sucukları")
        if (normRowBrand.length >= 4 && normBrand.contains(normRowBrand)) {
          return true;
        }
      }

      // 2. Check against Company Name ONLY when brand_name is absent or generic
      if (!hasRowBrand && normRowCompany.isNotEmpty) {
        final rcWords = normRowCompany
            .split(' ')
            .where((w) => w.isNotEmpty && !_corporateStopwords.contains(w))
            .toList();

        if (qbWords.length == 1) {
          final word = qbWords.first;
          if (!_corporateStopwords.contains(word) && rcWords.contains(word)) {
            return true;
          }
        } else {
          if (qbWords.every((w) => rcWords.contains(w))) {
            return true;
          }
        }
      }

      // If a valid brand was provided and did not match the blacklisted entity, DO NOT match!
      return false;
    }

    // 3. If brand is missing or unverified, fallback to exact/distinct product match
    if (normProduct.isNotEmpty && normProduct.length >= 8) {
      if (normProduct == normRowProduct) return true;

      final qpWords = normProduct.split(' ').where((w) => w.length > 3).toList();
      final rpWords = normRowProduct.split(' ').where((w) => w.length > 3).toList();
      if (qpWords.length >= 2 && qpWords.every((w) => rpWords.contains(w))) {
        return true;
      }
    }

    return false;
  }

  /// Checks if a product or brand exists in the Ministry's Taklit & Tağşiş SQLite database.
  static Future<TaklitTagsisItem?> checkTaklitTagsisStatus({
    required String productName,
    required String brandName,
  }) async {
    try {
      final Database db = await DatabaseHelper().database;
      final List<Map<String, dynamic>> results = await db.query('taklit_tagsis');

      for (var row in results) {
        final item = TaklitTagsisItem.fromMap(row);
        if (isItemMatching(item, productName: productName, brandName: brandName)) {
          return item;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Searches the Taklit & Tağşiş database by keyword.
  static Future<List<TaklitTagsisItem>> searchDatabase(String query) async {
    try {
      final Database db = await DatabaseHelper().database;
      final String q = '%${query.trim()}%';

      final List<Map<String, dynamic>> results = await db.query(
        'taklit_tagsis',
        where: 'brand_name LIKE ? OR company_name LIKE ? OR product_name LIKE ? OR category LIKE ? OR reason LIKE ?',
        whereArgs: [q, q, q, q, q],
        orderBy: 'announced_at DESC',
      );

      return results.map((row) => TaklitTagsisItem.fromMap(row)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Gets all items from local SQLite table.
  static Future<List<TaklitTagsisItem>> getAllItems() async {
    try {
      final Database db = await DatabaseHelper().database;
      final List<Map<String, dynamic>> results = await db.query(
        'taklit_tagsis',
        orderBy: 'announced_at DESC',
      );
      return results.map((row) => TaklitTagsisItem.fromMap(row)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Groups items by brand and returns aggregated brand entities.
  static Future<List<TaklitTagsisBrandGroup>> getGroupedBrands() async {
    final items = await getAllItems();
    return groupItemsByBrand(items);
  }

  /// Pure grouping function for items list.
  static List<TaklitTagsisBrandGroup> groupItemsByBrand(List<TaklitTagsisItem> items) {
    final Map<String, List<TaklitTagsisItem>> map = {};

    for (final item in items) {
      String key = item.brandName.trim();
      if (key.isEmpty || key == '-' || key.toLowerCase() == 'bilinmeyen marka') {
        key = _cleanCompanyName(item.companyName);
      }
      final normalizedKey = key.toUpperCase();
      map.putIfAbsent(normalizedKey, () => []).add(item);
    }

    final List<TaklitTagsisBrandGroup> groups = [];

    map.forEach((key, productList) {
      if (productList.isEmpty) return;

      final first = productList.first;
      String displayBrand = first.brandName.trim();
      if (displayBrand.isEmpty || displayBrand == '-' || displayBrand.toLowerCase() == 'bilinmeyen marka') {
        displayBrand = _cleanCompanyName(first.companyName);
      }

      final bool hasHazard = productList.any((p) => p.isHealthHazard);

      final Set<String> reasonsSet = {};
      for (final p in productList) {
        final clean = p.cleanReason;
        if (clean.isNotEmpty) {
          reasonsSet.add(clean);
        }
      }

      DateTime latestDate = productList.first.announcedAt;
      for (final p in productList) {
        if (p.announcedAt.isAfter(latestDate)) {
          latestDate = p.announcedAt;
        }
      }

      groups.add(TaklitTagsisBrandGroup(
        brandName: displayBrand,
        companyName: first.companyName,
        primaryCategory: first.category,
        hasHealthHazard: hasHazard,
        uniqueReasons: reasonsSet.toList(),
        products: productList,
        latestAnnouncedAt: latestDate,
      ));
    });

    // Sort by latest announced date descending
    groups.sort((a, b) => b.latestAnnouncedAt.compareTo(a.latestAnnouncedAt));
    return groups;
  }

  static String _cleanCompanyName(String rawCompany) {
    if (rawCompany.isEmpty) return 'Yerel Üretici';
    final parts = rawCompany.split('-');
    if (parts.isNotEmpty && parts[0].trim().length >= 3) {
      return parts[0].trim();
    }
    return rawCompany.trim();
  }

  /// Gets stored last sync date.
  static Future<DateTime?> getLastSyncDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ts = prefs.getInt(_prefLastSyncKey);
      if (ts != null) {
        return DateTime.fromMillisecondsSinceEpoch(ts);
      }
    } catch (_) {}
    return null;
  }

  /// Direct fallback scraper to official Tarım ve Orman Bakanlığı DataTables API
  static Future<List<Map<String, dynamic>>> _fetchFromMinistryDirectly() async {
    final List<Map<String, dynamic>> items = [];
    final client = http.Client();
    final categories = [
      {
        'name': 'Sağlığı Tehlikeye Düşürecek Gıdalar',
        'params': {
          'KamuoyuDuyuruAra.ListeTurId': '',
          'KamuoyuDuyuruAra.IdariYaptirimYasalDayanakIdler': '',
          'KamuoyuDuyuruAra.IdariYaptirimYasalDayanakId': '',
        },
      },
      {
        'name': 'Taklit/Tağşiş - Madde Eklenmesi',
        'params': {
          'KamuoyuDuyuruAra.ListeTurId': '304',
          'KamuoyuDuyuruAra.IdariYaptirimYasalDayanakId': '0',
        },
      },
      {
        'name': 'Taklit/Tağşiş - İçerik Eksikliği',
        'params': {
          'KamuoyuDuyuruAra.HaricTut': '304',
          'KamuoyuDuyuruAra.IdariYaptirimYasalDayanakId': '0',
        },
      },
    ];

    try {
      for (final cat in categories) {
        final Map<String, String> body = {
          'draw': '1',
          'start': '0',
          'length': '1000',
          'siteYayinDurumu': 'True',
          'KamuoyuDuyuruAra.DuyuruTarihi': '',
          'KamuoyuDuyuruAra.UrunGrupId': '',
          'order[0][column]': '0',
          'order[0][dir]': 'desc',
          'search[value]': '',
          'search[regex]': 'false',
        };
        body.addAll(cat['params'] as Map<String, String>);

        const cols = [
          'DuyuruTarihi',
          'FirmaAdi',
          'Marka',
          'UrunAdi',
          'Uygunsuzluk',
          'PartiSeriNo',
          'FirmaIlce',
          'FirmaIl',
          'UrunGrupAdi'
        ];
        for (int i = 0; i < cols.length; i++) {
          body['columns[$i][data]'] = cols[i];
          body['columns[$i][name]'] = cols[i];
          body['columns[$i][searchable]'] = 'true';
          body['columns[$i][orderable]'] = 'true';
          body['columns[$i][search][value]'] = '';
          body['columns[$i][search][regex]'] = 'false';
        }

        final res = await client.post(
          Uri.parse('https://guvenilirgida.tarimorman.gov.tr/GuvenilirGida/GKD/DataTablesList'),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'X-Requested-With': 'XMLHttpRequest',
            'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
          },
          body: body,
        ).timeout(const Duration(seconds: 8));

        if (res.statusCode == 200) {
          final Map<String, dynamic> parsed = jsonDecode(res.body);
          final List<dynamic> rawData = parsed['data'] as List<dynamic>? ?? [];
          for (final raw in rawData) {
            final rawDate = raw['DuyuruTarihi']?.toString() ?? '';
            final match = RegExp(r'\d+').firstMatch(rawDate);
            final int timestamp = match != null ? int.parse(match.group(0)!) : DateTime.now().millisecondsSinceEpoch;

            final company = (raw['FirmaAdi']?.toString() ?? '').trim();
            String brand = (raw['Marka']?.toString() ?? '').trim();
            final product = (raw['UrunAdi']?.toString() ?? '').trim();
            final reason = (raw['Uygunsuzluk']?.toString() ?? '').trim();
            final category = (raw['UrunGrupAdi']?.toString() ?? 'Gıda').trim();

            if ((brand.isEmpty || brand == '-') && company.isNotEmpty) {
              brand = company.split('-').first.trim();
            }

            items.add({
              'company_name': company.isNotEmpty ? company : 'Firma Belirtilmemiş',
              'brand_name': brand.isNotEmpty ? brand : 'Bilinmeyen Marka',
              'product_name': product.isNotEmpty ? product : 'Ürün',
              'reason': '[${cat['name']}] $reason',
              'category': category,
              'announced_at': timestamp,
            });
          }
        }
      }
    } catch (_) {} finally {
      client.close();
    }
    return items;
  }

  /// Hybrid sync: Tries Cloudflare Edge Proxy first, then direct Ministry portal fallback.
  static Future<int> syncLatestList() async {
    List<dynamic> items = [];

    // Step 1: Cloudflare Edge Proxy Check
    try {
      final url = Uri.parse('https://organicscore-edge-proxy.workers.dev/api/taklit-tagsis');
      final response = await http.get(url).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List && decoded.isNotEmpty) {
          items = decoded;
        }
      }
    } catch (_) {}

    // Step 2: Direct Ministry Fallback Scraper if Edge has no fresh data
    if (items.isEmpty) {
      items = await _fetchFromMinistryDirectly();
    }

    if (items.isEmpty) return 0;

    try {
      final Database db = await DatabaseHelper().database;
      int addedCount = 0;

      for (var item in items) {
        final int result = await db.insert('taklit_tagsis', {
          'company_name': item['company_name'],
          'brand_name': item['brand_name'],
          'product_name': item['product_name'],
          'reason': item['reason'],
          'category': item['category'] ?? 'Gıda',
          'announced_at': item['announced_at'] ?? DateTime.now().millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);

        if (result > 0) addedCount++;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefLastSyncKey, DateTime.now().millisecondsSinceEpoch);

      return addedCount;
    } catch (_) {}
    return 0;
  }
}
