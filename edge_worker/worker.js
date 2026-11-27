/**
 * OrganicScore / Kilerce Cloudflare Worker Edge API
 *
 * Modules:
 * - src/security.js: CORS/JSON/HMAC/RateLimit/Turkish search fold/Media URL signing
 * - src/entitlements.js: RevenueCat webhook + AdMob SSV ECDSA verification + daily free quota
 * - src/recipes_api.js: 23,933 recipe FTS5 search, pantry matching, quota-gated detail, signed R2 WebP proxy
 */

import {
  extractAppUserId,
  handleAdMobSsvCallback,
  handleGetEntitlement,
  handleRedeemPromoCode,
  handleRevenueCatWebhook,
  handleRewardedAdStep,
  utcDateString,
} from './src/entitlements.js';
import {
  handleOcrProductLabel,
  handleOcrReceipt,
} from './src/ocr_api.js';
import {
  handlePantryMatch,
  handleRecipeDetail,
  handleRecipesSearch,
  handleSignMediaBatch,
  handleSignedMedia,
} from './src/recipes_api.js';
import {
  checkRateLimit,
  clampNova,
  clampScore,
  isValidGs1Barcode,
  jsonResponse,
  safeJsonParse,
  simpleHash,
  verifyHmacSignature,
} from './src/security.js';

const DEFAULT_BOYCOTT_LIST = [
  { brand_name: 'Coca-Cola', parent_company: 'The Coca-Cola Company', boycott_status: 'FLAGGED', category: 'Icecek', reason: 'Gazze işgali ve İsrail bağlantısı / desteği nedeniyle boykot listesinde (BDS Hedefi).', evidence_url: 'https://www.boykot.co/d/coca-cola' },
  { brand_name: 'Fanta', parent_company: 'The Coca-Cola Company', boycott_status: 'FLAGGED', category: 'Icecek', reason: 'The Coca-Cola Company grup markası.', evidence_url: 'https://www.boykot.co/d/fanta' },
  { brand_name: 'Nestle', parent_company: 'Nestlé S.A.', boycott_status: 'FLAGGED', category: 'Yiyecek', reason: 'Osem ortaklığı ve işgal altındaki Filistin bölgelerindeki yatırımları.', evidence_url: 'https://www.boykot.co/d/nestle' },
  { brand_name: 'Danone', parent_company: 'Danone S.A.', boycott_status: 'CAUTION', category: 'Yiyecek', reason: 'Strauss Group ve İsrail gıda endüstrisi ortaklığı.', evidence_url: 'https://www.boykot.co/d/danone' },
  { brand_name: 'Pepsico', parent_company: 'PepsiCo, Inc.', boycott_status: 'FLAGGED', category: 'Yiyecek', reason: 'SodaStream ve İsrail merkezli gıda yatırımları.', evidence_url: 'https://www.boykot.co/d/pepsico' },
  { brand_name: 'Lipton', parent_company: 'Ekaterra / CVC Capital', boycott_status: 'CAUTION', category: 'Icecek', reason: 'Sürdürülebilirlik ve kurumsal bağlantı incelemesinde.', evidence_url: 'https://www.boykot.co/d/lipton' },
  { brand_name: 'Starbucks', parent_company: 'Starbucks Corporation', boycott_status: 'FLAGGED', category: 'Kahve', reason: 'Sendika ve Filistin yanlısı açıklamalara karşı dava ve kurumsal tutum.', evidence_url: 'https://www.boykot.co/d/starbucks' },
  { brand_name: "McDonald's", parent_company: "McDonald's Corporation", boycott_status: 'FLAGGED', category: 'Yiyecek', reason: 'İsrail ordusuna ücretsiz yemek ve askeri lojistik desteği (BDS Hedefi).', evidence_url: 'https://www.boykot.co/d/mcdonalds' },
  { brand_name: 'Burger King', parent_company: 'Restaurant Brands International', boycott_status: 'FLAGGED', category: 'Yiyecek', reason: 'İsrail askeri güçlerine ücretsiz kumanya desteği.', evidence_url: 'https://www.boykot.co/d/burger-king' },
  { brand_name: 'Puma', parent_company: 'Puma SE', boycott_status: 'FLAGGED', category: 'Giyim', reason: 'İsrail Futbol Federasyonu (İFA) sponsorluğu ve işgal yerleşimlerindeki takımlar.', evidence_url: 'https://www.boykot.co/d/puma' },
];

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers':
        'Content-Type, Authorization, X-OrganicScore-Signature, X-OrganicScore-Timestamp, X-Kilerce-User-Id',
    };

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    try {
      // Public/external webhooks, health, & signed media routes skip KV/isolate rate-limit writes
      if (url.pathname === '/health') {
        return jsonResponse({ status: 'ok', service: 'Kilerce-Edge-Proxy', version: '1.0.0' }, 200, corsHeaders);
      }

      if (url.pathname.startsWith('/api/media/') && request.method === 'GET') {
        const relPath = url.pathname.slice('/api/media/'.length);
        return await handleSignedMedia(request, env, corsHeaders, relPath);
      }

      const rateLimitOk = await checkRateLimit(request, env);
      if (!rateLimitOk) {
        return jsonResponse({ error: 'Rate limit exceeded' }, 429, corsHeaders);
      }

      if (url.pathname === '/api/webhooks/admob-ssv' && request.method === 'GET') {
        return await handleAdMobSsvCallback(request, env, corsHeaders);
      }

      if (url.pathname === '/api/webhooks/revenuecat' && request.method === 'POST') {
        const rawBody = await request.text();
        if (rawBody.length > 65536) {
          return jsonResponse({ error: 'Payload too large' }, 413, corsHeaders);
        }
        return await handleRevenueCatWebhook(request, env, corsHeaders, rawBody);
      }

      if (url.pathname === '/api/taklit-tagsis' && request.method === 'GET') {
        return await handleTaklitTagsis(env, corsHeaders);
      }

      if (url.pathname === '/api/boycott' && request.method === 'GET') {
        return await handleBoycottList(request, env, corsHeaders);
      }

      // Read body on POST requests and enforce client HMAC signature when HMAC_SECRET is configured
      let rawBody = '';
      if (request.method === 'POST') {
        rawBody = await request.text();
        const maxPostBodyBytes = url.pathname.startsWith('/api/ocr/') ? 2400000 : 32768;
        if (rawBody.length > maxPostBodyBytes) {
          return jsonResponse({ error: 'Payload too large' }, 413, corsHeaders);
        }
      }

      const requiresClientHmac =
        request.method === 'POST' ||
        url.pathname.startsWith('/api/recipes') ||
        url.pathname.startsWith('/api/entitlements');

      if (requiresClientHmac) {
        const sigOk = await verifyHmacSignature(request, rawBody, env);
        if (!sigOk) {
          return jsonResponse({ error: 'Unauthorized signature' }, 401, corsHeaders);
        }
      }

      // Recipe & Entitlement Routes
      if (url.pathname === '/api/entitlements/me' && request.method === 'GET') {
        return await handleGetEntitlement(request, env, corsHeaders);
      }

      if (url.pathname === '/api/entitlements/redeem-promo' && request.method === 'POST') {
        return await handleRedeemPromoCode(request, env, corsHeaders, rawBody);
      }

      if (url.pathname === '/api/entitlements/reward-ad-step' && request.method === 'POST') {
        return await handleRewardedAdStep(request, env, corsHeaders);
      }

      if (url.pathname === '/api/recipes/search' && request.method === 'GET') {
        return await handleRecipesSearch(request, env, corsHeaders);
      }

      if (url.pathname === '/api/recipes/match-pantry' && request.method === 'POST') {
        return await handlePantryMatch(request, env, corsHeaders, rawBody);
      }

      if (url.pathname.startsWith('/api/recipes/') && request.method === 'GET') {
        const recipeId = url.pathname.slice('/api/recipes/'.length);
        return await handleRecipeDetail(request, env, corsHeaders, recipeId);
      }

      if (url.pathname === '/api/media/sign-batch' && request.method === 'POST') {
        return await handleSignMediaBatch(request, env, corsHeaders, rawBody);
      }

      // Cost-Efficient Gemini 2.5 Flash-Lite OCR Endpoints
      if (url.pathname === '/api/ocr/receipt' && request.method === 'POST') {
        return await handleOcrReceipt(request, env, corsHeaders, rawBody);
      }

      if (url.pathname === '/api/ocr/product-label' && request.method === 'POST') {
        return await handleOcrProductLabel(request, env, corsHeaders, rawBody);
      }

      // Existing OrganicScore Product Endpoints
      if (url.pathname === '/api/analyze' && request.method === 'POST') {
        return await handleProductAnalyze(request, env, corsHeaders, rawBody);
      }

      if (url.pathname === '/api/crowdsource' && request.method === 'POST') {
        return await handleCrowdsource(env, corsHeaders, rawBody);
      }

      if (url.pathname === '/api/boycott/report' && request.method === 'POST') {
        return await handleBoycottReport(env, corsHeaders, rawBody);
      }

      return new Response('Not Found', { status: 404, headers: corsHeaders });
    } catch (err) {
      return jsonResponse(
        { error: 'Internal server error', detail: err?.message ? String(err.message).slice(0, 120) : 'unknown' },
        500,
        corsHeaders,
      );
    }
  },
};

async function handleProductAnalyze(request, env, corsHeaders, rawBody) {
  const body = safeJsonParse(rawBody);
  if (!body) {
    return jsonResponse({ error: 'Invalid JSON body' }, 400, corsHeaders);
  }
  const barcode = typeof body.barcode === 'string' ? body.barcode.trim().slice(0, 32) : '';
  const productName = typeof body.productName === 'string' ? body.productName.trim().slice(0, 160) : '';
  const ingredients = typeof body.ingredients === 'string' ? body.ingredients.trim().slice(0, 2000) : '';

  if (!barcode && !ingredients) {
    return jsonResponse({ error: 'Missing barcode or ingredients' }, 400, corsHeaders);
  }

  const cacheKey = `product:${barcode || simpleHash(ingredients)}`;

  if (env.ORGANIC_SCORE_KV) {
    try {
      const cachedResult = await env.ORGANIC_SCORE_KV.get(cacheKey);
      if (cachedResult) {
        const parsed = safeJsonParse(cachedResult);
        if (parsed) {
          return jsonResponse({
            ...parsed,
            cached: true,
            cache_source: 'Cloudflare_KV_Edge',
          }, 200, corsHeaders);
        }
      }

      const aiLimit = Math.max(1, Number(env.PRO_DAILY_AI_LIMIT) || 20);
      const actor = extractAppUserId(request) || request.headers.get('CF-Connecting-IP') || 'unknown';
      const aiQuotaKey = `ai_daily:${actor}:${utcDateString(Date.now())}`;
      const aiUsedRaw = await env.ORGANIC_SCORE_KV.get(aiQuotaKey);
      const aiUsed = aiUsedRaw ? Number(aiUsedRaw) || 0 : 0;
      if (aiUsed >= aiLimit) {
        return jsonResponse({
          error: 'AI_DAILY_LIMIT_EXCEEDED',
          message: 'Günlük yeni AI ürün analizi adil kullanım sınırına ulaşıldı. Önbellekteki barkod analizleri sınırsızdır.',
        }, 429, corsHeaders);
      }
      await env.ORGANIC_SCORE_KV.put(aiQuotaKey, String(aiUsed + 1), { expirationTtl: 86400 });
    } catch {
      // KV quota/rate-limit errors must not block product analysis
    }
  }

  const systemPrompt = `Sen bir uzman gıda biyokimyacısısın. Ürün adı ve içindekiler listesini analiz et. Yanıtı SADECE geçerli JSON olarak ver:
{
  "organic_score": 0-100 arası tamsayı,
  "nova_group": 1-4 arası tamsayı,
  "verdict": "Kısa özet kararı",
  "summary": "1-2 cümlelik sağlık açıklaması",
  "warnings": ["Uyarı 1", "Uyarı 2"],
  "alternatives": [{"name": "Sağlıklı Alternatif Ürün", "brand": "Marka", "reason": "Neden tercih edilmeli"}]
}`;

  const promptText = `Ürün: ${productName || 'Bilinmeyen'}\nİçindekiler: ${ingredients || 'Bulunamadı'}`;
  let aiResultJson;

  if (env.GEMINI_API_KEY) {
    const geminiResponse = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${env.GEMINI_API_KEY}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ parts: [{ text: systemPrompt }, { text: promptText }] }],
          generationConfig: { response_mime_type: 'application/json' },
        }),
      },
    );

    if (!geminiResponse.ok) {
      return jsonResponse({ error: 'Upstream AI service unavailable' }, 502, corsHeaders);
    }

    const geminiData = await geminiResponse.json();
    const rawText = geminiData?.candidates?.[0]?.content?.parts?.[0]?.text;
    aiResultJson = rawText ? safeJsonParse(rawText) : null;
    if (!aiResultJson) {
      return jsonResponse({ error: 'Invalid upstream AI response' }, 502, corsHeaders);
    }
  } else {
    aiResultJson = {
      organic_score: 72,
      nova_group: 3,
      verdict: 'Kabul Edilebilir İçerik',
      summary: 'Ürün orta düzeyde işlenmiş olup makul seviyede katkı maddesi içermektedir.',
      warnings: ['Porsiyon kontrolü tavsiye edilir.'],
      alternatives: [
        { name: 'Doğal Organik Alternatif', brand: 'Yerli Üretici', reason: 'Sıfır sentetik koruyucu' },
      ],
    };
  }

  if (env.ORGANIC_SCORE_KV) {
    try {
      await env.ORGANIC_SCORE_KV.put(cacheKey, JSON.stringify(aiResultJson), {
        expirationTtl: 60 * 60 * 24 * 30,
      });
    } catch {
      // Best-effort KV cache write
    }
  }

  return jsonResponse({
    ...aiResultJson,
    cached: false,
    cache_source: 'Gemini_2.5_Flash_Relay',
  }, 200, corsHeaders);
}

async function handleCrowdsource(env, corsHeaders, rawBody) {
  const payload = safeJsonParse(rawBody);
  if (!payload) {
    return jsonResponse({ error: 'Invalid JSON body' }, 400, corsHeaders);
  }

  const barcode = typeof payload.barcode === 'string' ? payload.barcode.trim() : '';
  if (!isValidGs1Barcode(barcode)) {
    return jsonResponse({ error: 'Invalid GS1 barcode' }, 400, corsHeaders);
  }

  const productName = typeof payload.product_name === 'string' ? payload.product_name.trim().slice(0, 140) : '';
  const brand = typeof payload.brand === 'string' ? payload.brand.trim().slice(0, 100) : '';
  const ingredientsText = typeof payload.ingredients_text === 'string' ? payload.ingredients_text.trim().slice(0, 2000) : '';

  if (!productName && !ingredientsText) {
    return jsonResponse({ error: 'Missing product details' }, 400, corsHeaders);
  }

  if (env.ORGANIC_SCORE_KV) {
    const pendingKey = `crowdsource:pending:${barcode}:${Date.now()}`;
    const productSummary = {
      barcode,
      product_name: productName,
      brand,
      ingredients_text: ingredientsText,
      organic_score: clampScore(payload.organic_score, 50),
      nova_group: clampNova(payload.nova_group, 3),
      verdict: 'Topluluk Doğrulamalı Ürün (İncelemede)',
      status: 'PENDING_REVIEW',
      submitted_at: Date.now(),
    };

    await env.ORGANIC_SCORE_KV.put(pendingKey, JSON.stringify(productSummary), {
      expirationTtl: 60 * 60 * 24 * 90,
    });
  }

  return jsonResponse({
    status: 'success',
    message: 'Topluluk katkısı doğrulama kuyruğuna başarıyla alındı.',
  }, 200, corsHeaders);
}

async function handleTaklitTagsis(env, corsHeaders) {
  if (env.ORGANIC_SCORE_KV) {
    const cachedTagsis = await env.ORGANIC_SCORE_KV.get('taklit_tagsis:latest');
    if (cachedTagsis) {
      return new Response(cachedTagsis, {
        headers: { ...corsHeaders, 'Content-Type': 'application/json', 'Cache-Control': 'public, max-age=1800' },
      });
    }
  }
  return jsonResponse([], 200, corsHeaders);
}

async function handleBoycottList(request, env, corsHeaders) {
  let boycottList = null;
  let etag = 'W/"boycott-v1.2.0"';

  if (env.ORGANIC_SCORE_KV) {
    const cachedBoycott = await env.ORGANIC_SCORE_KV.get('boycott:verified_list');
    if (cachedBoycott) {
      boycottList = safeJsonParse(cachedBoycott);
      etag = `W/"boycott-${simpleHash(cachedBoycott)}"`;
    }
  }

  const clientEtag = request.headers.get('If-None-Match');
  if (clientEtag && clientEtag === etag) {
    return new Response(null, {
      status: 304,
      headers: { ...corsHeaders, ETag: etag },
    });
  }

  if (!boycottList) {
    boycottList = DEFAULT_BOYCOTT_LIST;
  }

  return new Response(JSON.stringify(boycottList), {
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
      ETag: etag,
      'Cache-Control': 'public, max-age=3600',
    },
  });
}

async function handleBoycottReport(env, corsHeaders, rawBody) {
  const report = safeJsonParse(rawBody);
  if (!report) {
    return jsonResponse({ error: 'Invalid JSON body' }, 400, corsHeaders);
  }

  const brandName = typeof report.brand_name === 'string' ? report.brand_name.trim().slice(0, 120) : '';
  const productName = typeof report.product_name === 'string' ? report.product_name.trim().slice(0, 140) : '';
  const userReason = typeof report.user_reason === 'string' ? report.user_reason.trim().slice(0, 600) : '';
  const reportType = typeof report.report_type === 'string' ? report.report_type.trim().slice(0, 32) : '';

  if (!brandName && !productName) {
    return jsonResponse({ error: 'Missing brand_name or product_name' }, 400, corsHeaders);
  }
  if (userReason.length < 3) {
    return jsonResponse({ error: 'Missing user_reason' }, 400, corsHeaders);
  }

  const reportId = `report:${Date.now()}_${simpleHash(productName || brandName || 'item')}`;
  if (env.ORGANIC_SCORE_KV) {
    await env.ORGANIC_SCORE_KV.put(reportId, JSON.stringify({
      barcode: typeof report.barcode === 'string' ? report.barcode.trim().slice(0, 32) : '',
      brand_name: brandName,
      product_name: productName,
      report_type: reportType,
      user_reason: userReason,
      created_at: Date.now(),
      status: 'PENDING_REVIEW',
    }), {
      expirationTtl: 60 * 60 * 24 * 60,
    });
  }

  return jsonResponse({
    status: 'success',
    message: 'Boykot bildiriminiz doğrulama kuyruğuna başarıyla alındı.',
    report_id: reportId,
  }, 200, corsHeaders);
}
