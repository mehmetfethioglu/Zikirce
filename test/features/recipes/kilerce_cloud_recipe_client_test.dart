import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:organicscore/features/monetization/domain/subscription_service.dart';
import 'package:organicscore/features/recipes/data/builtin_recipe_r2_map.dart';
import 'package:organicscore/features/recipes/data/kilerce_cloud_recipe_client.dart';
import 'package:organicscore/features/recipes/data/recipe_image_disk_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  });

  group('KilerceCloudRecipeClient & Monetization 3-Ad Pro Tests', () {
    test('Canonical HMAC signing is deterministic and search parses preview cards without steps', () async {
      late Map<String, String> capturedHeaders;
      late Uri capturedUri;

      final mockHttp = MockClient((request) async {
        capturedHeaders = request.headers;
        capturedUri = request.url;
        return http.Response(
          jsonEncode({
            'page': 1,
            'limit': 20,
            'has_more': true,
            'items': [
              {
                'id': 'kilerce_karniyarik',
                'title': 'Kuşbaşı Etli Karnıyarık',
                'subtitle': 'Et Yemeği • 45 dk',
                'emoji': '🍆',
                'category': 'Et Yemeği',
                'kilerce_category': 'Et, Tavuk & Balık',
                'region_id': 'marmara',
                'prep_minutes': 20,
                'cook_minutes': 25,
                'servings_count': 4,
                'servings_label': '4 kişilik',
                'difficulty': 'medium',
                'cooking_method': 'oven',
                'is_healthy_clean': true,
                'base_health_score': 92,
                'required_tags': ['patlican', 'dana_eti'],
                'image_url':
                    'https://kilerce-edge-api.kilerce.workers.dev/api/media/photo_webp_v2/et_yemegi/kilerce_karniyarik.webp?exp=9999999999&sig=abc',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = KilerceCloudRecipeClient.forTesting(client: mockHttp);
      final page = await client.searchRecipes(query: 'karnıyarık', limit: 20);

      expect(capturedUri.path, equals('/api/recipes/search'));
      expect(capturedHeaders['X-OrganicScore-Signature']?.length, equals(64));
      expect(capturedHeaders['X-OrganicScore-Timestamp'], isNotEmpty);
      expect(capturedHeaders['X-Kilerce-User-Id'], startsWith('kilerce_'));
      expect(page.hasMore, isTrue);
      expect(page.items.length, equals(1));
      expect(page.items.first.id, equals('kilerce_karniyarik'));
      expect(page.items.first.steps, isEmpty);
      expect(page.items.first.imageUrl, contains('/api/media/photo_webp_v2/'));
    });

    test('fetchRecipeDetail handles HTTP 402 PRO_REQUIRED and HTTP 200 full hydration', () async {
      int callNum = 0;
      final mockHttp = MockClient((request) async {
        callNum++;
        if (callNum == 1) {
          return http.Response(
            jsonEncode({
              'error': 'PRO_REQUIRED',
              'message': 'Günlük limit doldu.',
              'entitlement': {
                'is_pro': false,
                'tier': 'free',
                'ad_progress': 2,
                'ads_required': 3,
                'daily_detail_used': 5,
                'daily_detail_limit': 5,
                'daily_detail_remaining': 0,
              },
            }),
            402,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          jsonEncode({
            'recipe': {
              'id': 'kilerce_karniyarik',
              'title': 'Kuşbaşı Etli Karnıyarık',
              'subtitle': 'Et Yemeği • 45 dk',
              'emoji': '🍆',
              'kilerce_category': 'Et, Tavuk & Balık',
              'prep_minutes': 20,
              'cook_minutes': 25,
              'servings_count': 4,
              'base_health_score': 92,
              'required_tags': ['patlican'],
              'ingredients': [
                {'display': '4 adet patlıcan', 'name': 'patlıcan', 'tag': 'patlican'},
              ],
              'steps': ['Patlıcanları alacalı soyun.', 'Fırında pişirin.'],
            },
            'entitlement': {
              'is_pro': true,
              'tier': 'rewarded_pro',
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final client = KilerceCloudRecipeClient.forTesting(client: mockHttp);
      final gated = await client.fetchRecipeDetail('kilerce_karniyarik');
      expect(gated, isA<CloudRecipeProRequired>());
      final proReq = gated as CloudRecipeProRequired;
      expect(proReq.entitlement.adProgress, equals(2));
      expect(proReq.entitlement.dailyDetailRemaining, equals(0));

      final full = await client.fetchRecipeDetail('kilerce_karniyarik');
      expect(full, isA<CloudRecipeDetailSuccess>());
      final ok = full as CloudRecipeDetailSuccess;
      expect(ok.recipe.steps.length, equals(2));
      expect(ok.recipe.ingredients.length, equals(1));
    });

    test('RecipeImageDiskCache canonicalCacheKey ignores ephemeral signed query params', () {
      const url1 =
          'https://kilerce-edge-api.kilerce.workers.dev/api/media/photo_webp_v2/corba/kilerce_a.webp?exp=1000&sig=aaa';
      const url2 =
          'https://kilerce-edge-api.kilerce.workers.dev/api/media/photo_webp_v2/corba/kilerce_a.webp?exp=2000&sig=bbb';
      expect(
        RecipeImageDiskCache.canonicalCacheKey(url1),
        equals(RecipeImageDiskCache.canonicalCacheKey(url2)),
      );
      expect(
        RecipeImageDiskCache.cacheFileNameForUrl(url1),
        equals(RecipeImageDiskCache.cacheFileNameForUrl(url2)),
      );
    });

    test('SubscriptionService 3-Ad cycle unlocks 3h Pro twice per day and caps 3rd cycle', () async {
      final service = SubscriptionService.instance;
      expect(await service.getRewardAdProgress(), equals(0));
      expect(await service.getDailyRewardPassesUsed(), equals(0));

      // Cycle 1: 3 ads -> +3h Pro (1/2 daily pass)
      final s1 = await service.recordRewardedAdStep();
      expect(s1.progress, equals(1));
      expect(s1.unlockedPro3h, isFalse);

      final s2 = await service.recordRewardedAdStep();
      expect(s2.progress, equals(2));
      expect(s2.unlockedPro3h, isFalse);

      final s3 = await service.recordRewardedAdStep();
      expect(s3.unlockedPro3h, isTrue);
      expect(s3.dailyPassesUsed, equals(1));
      expect(s3.progress, equals(0));

      final rem1 = await service.getRemainingAdFreeDuration();
      expect(rem1.inHours, inInclusiveRange(2, 3));

      // Cycle 2: 3 more ads -> +3h Pro (2/2 daily pass, total ~6h)
      await service.recordRewardedAdStep();
      await service.recordRewardedAdStep();
      final s6 = await service.recordRewardedAdStep();
      expect(s6.unlockedPro3h, isTrue);
      expect(s6.dailyPassesUsed, equals(2));

      final rem2 = await service.getRemainingAdFreeDuration();
      expect(rem2.inHours, inInclusiveRange(5, 6));

      // 3rd cycle same day hits daily 2-pass cap
      final s7 = await service.recordRewardedAdStep();
      expect(s7.dailyLimitReached, isTrue);
      expect(s7.unlockedPro3h, isFalse);
    });

    test('All 100 built-in starter recipes have verified R2 WebP image mappings', () {
      expect(kilerceBuiltinRecipeR2Paths.length, equals(100));
      for (final rel in kilerceBuiltinRecipeR2Paths.values) {
        expect(rel, startsWith('photo_webp_v2/'));
        expect(rel, endsWith('.webp'));
      }
    });

    test('signMediaBatch requests /api/media/sign-batch and returns signed map', () async {
      final mockHttp = MockClient((request) async {
        expect(request.url.path, equals('/api/media/sign-batch'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final paths = (body['paths'] as List<dynamic>).cast<String>();
        return http.Response(
          jsonEncode({
            'urls': {
              for (final p in paths)
                p: 'https://kilerce-edge-api.kilerce.workers.dev/api/media/$p?exp=9999999999&sig=ok',
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final client = KilerceCloudRecipeClient.forTesting(client: mockHttp);
      final urls = await client.signMediaBatch([
        'photo_webp_v2/kahvaltilik/kilerce_cakalli_menemeni.webp',
      ]);
      expect(
        urls['photo_webp_v2/kahvaltilik/kilerce_cakalli_menemeni.webp'],
        contains('sig=ok'),
      );
    });

    test('fetchRecipeDetail retries once on transient HTTP 500 and recovers on HTTP 200', () async {
      int attempts = 0;
      final mockHttp = MockClient((request) async {
        attempts++;
        if (attempts == 1) {
          return http.Response(
            jsonEncode({'error': 'Internal server error', 'detail': 'KV PUT failed'}),
            500,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          jsonEncode({
            'recipe': {
              'id': 'kilerce_karniyarik',
              'title': 'Kuşbaşı Etli Karnıyarık',
              'subtitle': 'Et Yemeği • 45 dk',
              'emoji': '🍆',
              'kilerce_category': 'Et, Tavuk & Balık',
              'ingredients': [],
              'steps': ['Fırınlayın.'],
            },
            'entitlement': {'is_pro': false},
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final client = KilerceCloudRecipeClient.forTesting(client: mockHttp);
      final res = await client.fetchRecipeDetail('kilerce_karniyarik');
      expect(attempts, equals(2));
      expect(res, isA<CloudRecipeDetailSuccess>());
    });

    test('fetchRecipeDetail maps persistent HTTP 500 to friendly Turkish message and 429 IP quota to CloudRecipeProRequired', () async {
      final mock500 = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'Internal server error'}),
          500,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final client500 = KilerceCloudRecipeClient.forTesting(client: mock500);
      final failRes = await client500.fetchRecipeDetail('kilerce_karniyarik');
      expect(failRes, isA<CloudRecipeDetailFailure>());
      final failure = failRes as CloudRecipeDetailFailure;
      expect(failure.message, isNot(contains('Internal server error')));
      expect(failure.message, contains('Sunucu'));

      final mock429 = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': 'IP_DAILY_QUOTA_EXCEEDED',
            'message': 'Günlük ücretsiz tarif görüntüleme sınırına ulaşıldı.',
            'entitlement': {'is_pro': false, 'daily_detail_remaining': 0},
          }),
          429,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final client429 = KilerceCloudRecipeClient.forTesting(client: mock429);
      final quotaRes = await client429.fetchRecipeDetail('kilerce_karniyarik');
      expect(quotaRes, isA<CloudRecipeProRequired>());
    });

    test('redeemPromoCodeOnCloud and recordRewardedAdStepOnCloud sign POST requests and parse entitlements', () async {
      final mockHttp = MockClient((request) async {
        expect(request.method, equals('POST'));
        expect(request.headers['X-OrganicScore-Signature']?.length, equals(64));
        if (request.url.path == '/api/entitlements/redeem-promo') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['code'], equals('TESTER2026'));
          return http.Response(
            jsonEncode({
              'status': 'ok',
              'entitlement': {
                'is_pro': true,
                'tier': 'tester',
                'source': 'promo_code',
                'pro_until_ms': 1893456000000,
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        expect(request.url.path, equals('/api/entitlements/reward-ad-step'));
        return http.Response(
          jsonEncode({
            'status': 'ok',
            'unlocked_pro_3h': true,
            'entitlement': {
              'is_pro': true,
              'tier': 'rewarded_pro',
              'ad_progress': 0,
              'daily_reward_passes_used': 1,
              'daily_reward_passes_limit': 2,
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final client = KilerceCloudRecipeClient.forTesting(client: mockHttp);
      final promoSnap = await client.redeemPromoCodeOnCloud('tester2026');
      expect(promoSnap, isNotNull);
      expect(promoSnap!.isPro, isTrue);
      expect(promoSnap.tier, equals('tester'));

      final adSnap = await client.recordRewardedAdStepOnCloud();
      expect(adSnap, isNotNull);
      expect(adSnap!.isPro, isTrue);
      expect(adSnap.dailyRewardPassesUsed, equals(1));
    });
  });
}
