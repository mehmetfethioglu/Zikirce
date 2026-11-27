import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../monetization/domain/kilerce_pro_models.dart';
import '../domain/recipe_models.dart';
import 'kilerce_edge_config.dart';

/// Paginated preview search result from Kilerce Cloudflare D1 API.
class CloudRecipeSearchPage {
  final int page;
  final int limit;
  final bool hasMore;
  final List<KilerRecipe> items;

  const CloudRecipeSearchPage({
    required this.page,
    required this.limit,
    required this.hasMore,
    required this.items,
  });
}

/// Sealed result returned when hydrating a full cloud recipe detail.
sealed class CloudRecipeDetailResult {
  const CloudRecipeDetailResult();
}

class CloudRecipeDetailSuccess extends CloudRecipeDetailResult {
  final KilerRecipe recipe;
  final KilerceEntitlementSnapshot entitlement;

  const CloudRecipeDetailSuccess({
    required this.recipe,
    required this.entitlement,
  });
}

class CloudRecipeProRequired extends CloudRecipeDetailResult {
  final KilerceEntitlementSnapshot entitlement;
  final String message;

  const CloudRecipeProRequired({
    required this.entitlement,
    required this.message,
  });
}

class CloudRecipeDetailFailure extends CloudRecipeDetailResult {
  final String message;

  const CloudRecipeDetailFailure(this.message);
}

/// DIP gateway interface for Kilerce's 23,933-recipe Cloudflare Edge API.
abstract interface class KilerceCloudRecipeGateway {
  Future<String> getOrCreateAppUserId();

  Future<CloudRecipeSearchPage> searchRecipes({
    String query = '',
    String? kilerceCategory,
    String? regionId,
    bool healthyOnly = false,
    bool veganOnly = false,
    bool glutenFree = false,
    int? maxMinutes,
    int page = 1,
    int limit = 20,
  });

  Future<CloudRecipeSearchPage> matchPantry({
    required List<String> pantryTags,
    List<String> expiringTags = const [],
    String? kilerceCategory,
    int limit = 20,
    int offset = 0,
  });

  Future<CloudRecipeDetailResult> fetchRecipeDetail(String recipeId);

  Future<Map<String, String>> signMediaBatch(List<String> relPaths);

  Future<KilerceEntitlementSnapshot?> fetchEntitlement();

  Future<KilerceEntitlementSnapshot?> redeemPromoCodeOnCloud(String code);

  Future<KilerceEntitlementSnapshot?> recordRewardedAdStepOnCloud();
}

/// Concrete HMAC-signed HTTP client communicating with Kilerce Cloudflare Worker.
class KilerceCloudRecipeClient implements KilerceCloudRecipeGateway {
  static final KilerceCloudRecipeClient instance =
      KilerceCloudRecipeClient._internal();

  static const String appUserIdPrefsKey = 'kilerce_app_user_id_v1';
  static const Duration _timeout = Duration(seconds: 12);

  final http.Client _client;
  final String _baseUrl;
  final String _hmacSecret;

  String? _cachedAppUserId;

  KilerceCloudRecipeClient._internal({
    http.Client? client,
    String? baseUrl,
    String? hmacSecret,
  })  : _client = client ?? http.Client(),
        _baseUrl = (baseUrl ?? KilerceEdgeConfig.apiBaseUrl).trim(),
        _hmacSecret = (hmacSecret ?? KilerceEdgeConfig.hmacSecret).trim();

  @visibleForTesting
  factory KilerceCloudRecipeClient.forTesting({
    required http.Client client,
    String baseUrl = 'https://kilerce.example.workers.dev',
    String hmacSecret = 'test-hmac-secret',
  }) {
    return KilerceCloudRecipeClient._internal(
      client: client,
      baseUrl: baseUrl,
      hmacSecret: hmacSecret,
    );
  }

  /// Generates canonical HMAC-SHA256 hex digest matching `edge_worker/src/security.js`.
  static String signCanonicalRequest({
    required String secret,
    required int timestampSec,
    required String method,
    required String wirePathAndQuery,
    String body = '',
  }) {
    final canonical =
        '$timestampSec.${method.toUpperCase()}.$wirePathAndQuery.$body';
    final key = utf8.encode(secret);
    final payload = utf8.encode(canonical);
    return Hmac(sha256, key).convert(payload).toString();
  }

  @override
  Future<String> getOrCreateAppUserId() async {
    if (_cachedAppUserId != null && _cachedAppUserId!.isNotEmpty) {
      return _cachedAppUserId!;
    }
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(milliseconds: 250),
      );
      final existing = (prefs.getString(appUserIdPrefsKey) ?? '').trim();
      if (existing.isNotEmpty) {
        _cachedAppUserId = existing;
        return existing;
      }
      final rng = Random.secure();
      final bytes = List<int>.generate(12, (_) => rng.nextInt(256));
      final hex =
          bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      final generated = 'kilerce_$hex';
      await prefs
          .setString(appUserIdPrefsKey, generated)
          .timeout(const Duration(milliseconds: 250));
      _cachedAppUserId = generated;
      return generated;
    } catch (e) {
      debugPrint('KilerceCloudRecipeClient.getOrCreateAppUserId fallback: $e');
      return 'kilerce_guest_session';
    }
  }

  Map<String, String> _buildSignedHeaders({
    required String method,
    required Uri uri,
    required String appUserId,
    String body = '',
    bool includeJsonContentType = false,
  }) {
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final wirePathAndQuery =
        uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
    final headers = <String, String>{
      'X-Kilerce-User-Id': appUserId,
      'X-OrganicScore-Timestamp': '$ts',
    };
    if (_hmacSecret.isNotEmpty) {
      headers['X-OrganicScore-Signature'] = signCanonicalRequest(
        secret: _hmacSecret,
        timestampSec: ts,
        method: method,
        wirePathAndQuery: wirePathAndQuery,
        body: body,
      );
    }
    if (includeJsonContentType) {
      headers['Content-Type'] = 'application/json';
    }
    return headers;
  }

  Uri _buildUri(String path, [Map<String, String>? queryParams]) {
    final base = Uri.parse(_baseUrl);
    final cleanParams = <String, String>{};
    if (queryParams != null) {
      for (final entry in queryParams.entries) {
        if (entry.value.isNotEmpty) {
          cleanParams[entry.key] = entry.value;
        }
      }
    }
    return base.replace(
      path: path,
      queryParameters: cleanParams.isEmpty ? null : cleanParams,
    );
  }

  @override
  Future<CloudRecipeSearchPage> searchRecipes({
    String query = '',
    String? kilerceCategory,
    String? regionId,
    bool healthyOnly = false,
    bool veganOnly = false,
    bool glutenFree = false,
    int? maxMinutes,
    int page = 1,
    int limit = 20,
  }) async {
    final uri = _buildUri('/api/recipes/search', {
      'q': query.trim(),
      'kilerce_category': (kilerceCategory ?? '').trim(),
      'region_id': (regionId ?? '').trim(),
      if (healthyOnly) 'healthy_only': '1',
      if (veganOnly) 'vegan': '1',
      if (glutenFree) 'gluten_free': '1',
      if (maxMinutes != null && maxMinutes > 0) 'max_minutes': '$maxMinutes',
      'page': '${page.clamp(1, 50)}',
      'limit': '${limit.clamp(1, 20)}',
    });

    final userId = await getOrCreateAppUserId();
    final resp = await _client
        .get(uri, headers: _buildSignedHeaders(method: 'GET', uri: uri, appUserId: userId))
        .timeout(_timeout);

    if (resp.statusCode != 200) {
      throw HttpException('Search failed (${resp.statusCode})');
    }

    final map = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final rawItems = (map['items'] as List<dynamic>? ?? const []);
    return CloudRecipeSearchPage(
      page: (map['page'] as num?)?.toInt() ?? page,
      limit: (map['limit'] as num?)?.toInt() ?? limit,
      hasMore: map['has_more'] == true,
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(recipeFromCloudJson)
          .toList(),
    );
  }

  @override
  Future<CloudRecipeSearchPage> matchPantry({
    required List<String> pantryTags,
    List<String> expiringTags = const [],
    String? kilerceCategory,
    int limit = 20,
    int offset = 0,
  }) async {
    final uri = _buildUri('/api/recipes/match-pantry');
    final payloadMap = <String, dynamic>{
      'pantry_tags': pantryTags.take(60).toList(),
      if (expiringTags.isNotEmpty)
        'expiring_tags': expiringTags.take(30).toList(),
      if (kilerceCategory != null && kilerceCategory.trim().isNotEmpty)
        'kilerce_category': kilerceCategory.trim(),
      'limit': limit.clamp(1, 20),
      'offset': offset.clamp(0, 200),
    };
    final body = jsonEncode(payloadMap);
    final userId = await getOrCreateAppUserId();
    final resp = await _client
        .post(
          uri,
          headers: _buildSignedHeaders(
            method: 'POST',
            uri: uri,
            appUserId: userId,
            body: body,
            includeJsonContentType: true,
          ),
          body: body,
        )
        .timeout(_timeout);

    if (resp.statusCode != 200) {
      throw HttpException('Pantry match failed (${resp.statusCode})');
    }

    final map = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final rawItems = (map['items'] as List<dynamic>? ?? const []);
    return CloudRecipeSearchPage(
      page: 1,
      limit: (map['limit'] as num?)?.toInt() ?? limit,
      hasMore: map['has_more'] == true,
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(recipeFromCloudJson)
          .toList(),
    );
  }

  @override
  Future<CloudRecipeDetailResult> fetchRecipeDetail(String recipeId) async {
    final cleanId = recipeId.trim();
    if (cleanId.isEmpty) {
      return const CloudRecipeDetailFailure('Geçersiz tarif kimliği.');
    }

    try {
      final uri = _buildUri('/api/recipes/${Uri.encodeComponent(cleanId)}');
      http.Response resp = await _sendSignedGet(uri);
      if (resp.statusCode >= 500) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        resp = await _sendSignedGet(uri);
      }

      final dynamic decoded = jsonDecode(utf8.decode(resp.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        return const CloudRecipeDetailFailure(
          'Sunucudan geçersiz yanıt alındı.',
        );
      }

      final String? serverErrorCode = decoded['error'] as String?;
      if (resp.statusCode == 402 ||
          (resp.statusCode == 429 &&
              serverErrorCode == 'IP_DAILY_QUOTA_EXCEEDED')) {
        final entJson = decoded['entitlement'];
        final entitlement = entJson is Map<String, dynamic>
            ? KilerceEntitlementSnapshot.fromJson(entJson)
            : const KilerceEntitlementSnapshot(dailyDetailRemaining: 0);
        return CloudRecipeProRequired(
          entitlement: entitlement,
          message: (decoded['message'] as String?) ??
              'Günlük 5 ücretsiz tarif limitiniz doldu. 3 reklam izleyerek 3 saat Pro açabilirsiniz.',
        );
      }

      if (resp.statusCode != 200) {
        return CloudRecipeDetailFailure(
          _mapFriendlyDetailError(
            statusCode: resp.statusCode,
            serverMessage: decoded['message'] as String?,
          ),
        );
      }

      final recipeJson = decoded['recipe'];
      final entJson = decoded['entitlement'];
      if (recipeJson is! Map<String, dynamic>) {
        return const CloudRecipeDetailFailure('Tarif verisi eksik.');
      }

      return CloudRecipeDetailSuccess(
        recipe: recipeFromCloudJson(recipeJson),
        entitlement: entJson is Map<String, dynamic>
            ? KilerceEntitlementSnapshot.fromJson(entJson)
            : const KilerceEntitlementSnapshot(),
      );
    } catch (e) {
      debugPrint('KilerceCloudRecipeClient.fetchRecipeDetail error: $e');
      return const CloudRecipeDetailFailure(
        'Tarif detayına erişmek için internet bağlantısı gerekiyor.',
      );
    }
  }

  Future<http.Response> _sendSignedGet(Uri uri) async {
    final userId = await getOrCreateAppUserId();
    return _client
        .get(
          uri,
          headers: _buildSignedHeaders(
            method: 'GET',
            uri: uri,
            appUserId: userId,
          ),
        )
        .timeout(_timeout);
  }

  static String _mapFriendlyDetailError({
    required int statusCode,
    String? serverMessage,
  }) {
    final trimmed = serverMessage?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
    if (statusCode == 404) {
      return 'Bu tarif şu an katalogda bulunamadı.';
    }
    if (statusCode == 401) {
      return 'Oturum doğrulaması yenileniyor, lütfen tekrar deneyin.';
    }
    if (statusCode >= 500) {
      return 'Sunucu şu an yoğun, lütfen birkaç saniye sonra tekrar deneyin.';
    }
    return 'Tarif detayı yüklenemedi ($statusCode).';
  }

  @override
  Future<Map<String, String>> signMediaBatch(List<String> relPaths) async {
    final cleaned = relPaths
        .map((p) => p.trim())
        .where((p) => p.startsWith('photo_webp_v2/') && p.endsWith('.webp'))
        .toSet()
        .take(120)
        .toList();
    if (cleaned.isEmpty) return const {};

    try {
      final uri = _buildUri('/api/media/sign-batch');
      final body = jsonEncode({'paths': cleaned});
      final userId = await getOrCreateAppUserId();
      final resp = await _client
          .post(
            uri,
            headers: _buildSignedHeaders(
              method: 'POST',
              uri: uri,
              appUserId: userId,
              body: body,
              includeJsonContentType: true,
            ),
            body: body,
          )
          .timeout(_timeout);
      if (resp.statusCode != 200) return const {};
      final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
      if (decoded is! Map<String, dynamic>) return const {};
      final rawUrls = decoded['urls'];
      if (rawUrls is! Map) return const {};
      return {
        for (final entry in rawUrls.entries)
          if (entry.value is String && (entry.value as String).isNotEmpty)
            entry.key.toString(): entry.value as String,
      };
    } catch (e) {
      debugPrint('KilerceCloudRecipeClient.signMediaBatch error: $e');
      return const {};
    }
  }

  @override
  Future<KilerceEntitlementSnapshot?> fetchEntitlement() async {
    try {
      final uri = _buildUri('/api/entitlements/me');
      final userId = await getOrCreateAppUserId();
      final resp = await _client
          .get(
            uri,
            headers: _buildSignedHeaders(
              method: 'GET',
              uri: uri,
              appUserId: userId,
            ),
          )
          .timeout(_timeout);
      if (resp.statusCode != 200) return null;
      final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
      if (decoded is! Map<String, dynamic>) return null;
      final entJson = decoded['entitlement'];
      if (entJson is! Map<String, dynamic>) return null;
      return KilerceEntitlementSnapshot.fromJson(entJson);
    } catch (e) {
      debugPrint('KilerceCloudRecipeClient.fetchEntitlement error: $e');
      return null;
    }
  }

  @override
  Future<KilerceEntitlementSnapshot?> redeemPromoCodeOnCloud(String code) {
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) return Future<KilerceEntitlementSnapshot?>.value(null);
    return _postEntitlementAction(
      '/api/entitlements/redeem-promo',
      {'code': clean},
    );
  }

  @override
  Future<KilerceEntitlementSnapshot?> recordRewardedAdStepOnCloud() {
    return _postEntitlementAction('/api/entitlements/reward-ad-step', const {});
  }

  Future<KilerceEntitlementSnapshot?> _postEntitlementAction(
    String path,
    Map<String, dynamic> payload,
  ) async {
    try {
      final uri = _buildUri(path);
      final body = jsonEncode(payload);
      final userId = await getOrCreateAppUserId();
      final resp = await _client
          .post(
            uri,
            headers: _buildSignedHeaders(
              method: 'POST',
              uri: uri,
              appUserId: userId,
              body: body,
              includeJsonContentType: true,
            ),
            body: body,
          )
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) return null;
      final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
      if (decoded is! Map<String, dynamic>) return null;
      final entJson = decoded['entitlement'];
      if (entJson is! Map<String, dynamic>) return null;
      return KilerceEntitlementSnapshot.fromJson(entJson);
    } catch (e) {
      debugPrint('KilerceCloudRecipeClient._postEntitlementAction($path) error: $e');
      return null;
    }
  }

  /// Maps Cloudflare D1/Worker JSON payload into domain [KilerRecipe].
  static KilerRecipe recipeFromCloudJson(Map<String, dynamic> json) {
    final reqTags = _stringList(json['required_tags']);
    final optTags = _stringList(json['optional_tags']);
    final badges = _stringList(json['clean_label_badges']);
    final rawSlots = _stringList(json['meal_slots']);
    final slots = rawSlots.isEmpty
        ? const [MealSlot.mainCourse]
        : rawSlots.map(MealSlot.fromDb).toList();

    final rawIngredients = (json['ingredients'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((m) {
      final num? amt = m['amount'] as num?;
      return RecipeIngredient(
        tag: (m['tag'] as String?) ?? '',
        name: ((m['display'] as String?)?.trim().isNotEmpty ?? false)
            ? (m['display'] as String).trim()
            : ((m['name'] as String?) ?? ''),
        amount: amt == null ? 0 : amt.toDouble(),
        unit: amt == null ? '' : ((m['unit'] as String?) ?? ''),
        isOptional: m['is_optional'] == true || m['is_optional'] == 1,
        isPantryStaple:
            m['is_pantry_staple'] == true || m['is_pantry_staple'] == 1,
      );
    }).toList();

    final rawSteps = _stringList(json['steps']);
    final kilerceCategory = (json['kilerce_category'] as String?) ??
        RecipeCategoryRegistry.vegOliveOil;
    final subCat = (json['category'] as String?) ?? kilerceCategory;
    final isHealthy = json['is_healthy_clean'] == true;
    final baseScore = (json['base_health_score'] as num?)?.toInt() ?? 80;
    final prep = (json['prep_minutes'] as num?)?.toInt() ?? 15;
    final cook = (json['cook_minutes'] as num?)?.toInt() ?? 20;
    final servings = (json['servings_count'] as num?)?.toInt() ?? 2;

    return KilerRecipe(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      subtitle: (json['subtitle'] as String?) ?? subCat,
      emoji: (json['emoji'] as String?) ?? '🍽️',
      category: kilerceCategory,
      regionId:
          (json['region_id'] as String?) ?? TurkishRegionRegistry.tumTurkiye,
      originCity: subCat,
      prepMinutes: prep,
      cookMinutes: cook,
      defaultServings: servings > 0 ? servings : 2,
      portionGram: 260,
      calories: isHealthy ? 285 : 360,
      proteinGrams: 12,
      fiberGrams: 5,
      carbsGrams: 28,
      fatGrams: 12,
      baseHealthScore: baseScore,
      difficulty: RecipeDifficulty.fromName(json['difficulty'] as String?),
      cookingMethod: CookingMethod.fromCode(json['cooking_method'] as String?),
      requiredTags: reqTags,
      optionalTags: optTags,
      ingredients: rawIngredients,
      steps: rawSteps,
      containsGluten: json['contains_gluten'] == true,
      containsLactose: json['contains_lactose'] == true,
      isVegan: json['is_vegan'] == true,
      isChildFriendly: isHealthy,
      isLowGlycemic: json['is_refined_sugar_free'] == true,
      isLowSodium: true,
      cleanLabelBadges:
          badges.isEmpty ? const ['Ev Yapımı Kilerce Katalogu'] : badges,
      mealSlots: slots,
      chefTip:
          'Kilerce Bulut Katalogu • ${json['servings_label'] ?? '$servings kişilik'}',
      imageUrl: (json['image_url'] as String?)?.trim(),
      photoCredit: 'Kilerce Stüdyo',
      sourceReference: 'Kilerce 23.933+ Ev Tarifleri',
    );
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
}

class HttpException implements Exception {
  final String message;
  const HttpException(this.message);
  @override
  String toString() => message;
}
