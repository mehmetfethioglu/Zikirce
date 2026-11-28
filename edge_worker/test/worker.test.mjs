import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

import worker from '../worker.js';
import { resetRecipeCachesForTesting } from '../src/recipes_api.js';
import { hmacSha256Hex } from '../src/security.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const SCHEMA_PATH = path.resolve(__dirname, '../migrations/0001_init_recipes_and_entitlements.sql');
const MIGRATION_002_PATH = path.resolve(__dirname, '../migrations/0002_reward_daily_passes.sql');

class MockD1Statement {
  constructor(db, sql, params = []) {
    this.db = db;
    this.sql = sql;
    this.params = params;
  }

  bind(...args) {
    const clean = args.map((v) => (v === undefined ? null : v));
    return new MockD1Statement(this.db, this.sql, clean);
  }

  async first() {
    const row = this.db.prepare(this.sql).get(...this.params);
    return row ?? null;
  }

  async all() {
    const results = this.db.prepare(this.sql).all(...this.params);
    return { results };
  }

  async run() {
    this.db.prepare(this.sql).run(...this.params);
    return { success: true };
  }
}

class MockD1Database {
  constructor() {
    this.db = new DatabaseSync(':memory:');
    this.db.exec(fs.readFileSync(SCHEMA_PATH, 'utf8'));
    this.db.exec(fs.readFileSync(MIGRATION_002_PATH, 'utf8'));
  }

  prepare(sql) {
    return new MockD1Statement(this.db, sql);
  }
}

class MockKVNamespace {
  constructor() {
    this.store = new Map();
  }

  async get(key) {
    return this.store.has(key) ? this.store.get(key) : null;
  }

  async put(key, value) {
    this.store.set(key, String(value));
  }
}

class MockR2Bucket {
  constructor() {
    this.objects = new Map();
  }

  putObject(key, bytes, contentType = 'image/webp') {
    this.objects.set(key, {
      body: bytes,
      httpMetadata: { contentType },
      httpEtag: `"etag-${key}"`,
    });
  }

  async get(key) {
    return this.objects.get(key) ?? null;
  }
}

function seedSampleRecipes(d1) {
  const recipes = [
    {
      id: 'kilerce_karniyarik',
      title: 'Fırında Zeytinyağlı Karnıyarık',
      subtitle: 'Ana Yemek • 45 dk • 4 kişilik',
      emoji: '🍆',
      category: 'Sebze Yemekleri',
      kilerce_category: 'Sebze & Zeytinyağlı',
      region_id: 'marmara',
      total_minutes: 45,
      is_healthy_clean: 1,
      is_vegan: 0,
      contains_gluten: 0,
      quality_score: 96,
      required_tags: ['patlican', 'kiyma', 'domates', 'sogan'],
      ingredients: [
        { display: '4 adet patlıcan', name: 'patlıcan', tag: 'patlican', is_optional: false, is_pantry_staple: false },
        { display: '250 g kıyma', name: 'kıyma', tag: 'kiyma', is_optional: false, is_pantry_staple: false },
      ],
      steps: ['Patlıcanları alacalı soyup fırınlayın.', 'İç harcı doldurup 20 dakika pişirin.'],
      rel_path: 'photo_webp_v2/sebze_zeytinyagli/kilerce_karniyarik.webp',
      search_fold: 'firinda zeytinyagli karniyarik sebze yemekleri patlican kiyma domates sogan',
    },
    {
      id: 'kilerce_mercimek_corbasi',
      title: 'Süzme Kırmızı Mercimek Çorbası',
      subtitle: 'Çorba • 25 dk • 4 kişilik',
      emoji: '🥣',
      category: 'Çorba',
      kilerce_category: 'Çorba',
      region_id: 'ic_anadolu',
      total_minutes: 25,
      is_healthy_clean: 1,
      is_vegan: 1,
      contains_gluten: 0,
      quality_score: 92,
      required_tags: ['kirmizi_mercimek', 'sogan', 'havuc'],
      ingredients: [
        { display: '1 su bardağı kırmızı mercimek', name: 'kırmızı mercimek', tag: 'kirmizi_mercimek', is_optional: false, is_pantry_staple: false },
        { display: '1 adet soğan', name: 'soğan', tag: 'sogan', is_optional: false, is_pantry_staple: true },
      ],
      steps: ['Mercimeği yıkayın.', 'Sebzelerle haşlayıp blenderdan geçirin.'],
      rel_path: 'photo_webp_v2/corba/kilerce_mercimek_corbasi.webp',
      search_fold: 'suzme kirmizi mercimek corbasi corba sogan havuc',
    },
  ];

  let ingSeqId = 1;
  for (const r of recipes) {
    d1.db.prepare(`
      INSERT INTO recipes (
        id, source, title, subtitle, emoji, category, kilerce_category, region_id,
        prep_minutes, cook_minutes, total_minutes, servings_count, servings_unit, servings_label,
        difficulty, cooking_method, contains_gluten, contains_lactose, is_vegan, is_vegetarian,
        has_margarine, is_refined_sugar_free, is_healthy_clean, base_health_score, quality_score,
        clean_label_badges_json, diet_tags_json, meal_slots_json, required_tags_json, optional_tags_json,
        ingredients_json, steps_json, image_rel_path, search_fold
      ) VALUES (?, 'yemek_com', ?, ?, ?, ?, ?, ?, 15, ?, ?, 4, 'kisilik', '4 kişilik', 'easy', 'oven',
        ?, 0, ?, 1, 0, 1, ?, 94, ?, '["Ev Yapımı"]', '[]', '["MAIN_COURSE"]', ?, '[]', ?, ?, ?, ?)
    `).run(
      r.id, r.title, r.subtitle, r.emoji, r.category, r.kilerce_category, r.region_id,
      r.total_minutes - 15, r.total_minutes, r.contains_gluten, r.is_vegan, r.is_healthy_clean,
      r.quality_score, JSON.stringify(r.required_tags), JSON.stringify(r.ingredients),
      JSON.stringify(r.steps), r.rel_path, r.search_fold,
    );

    d1.db.prepare('INSERT INTO recipes_fts (recipe_id, title, ingredients_text, search_fold) VALUES (?, ?, ?, ?)')
      .run(r.id, r.title, r.required_tags.join(' '), r.search_fold);

    r.ingredients.forEach((ing, idx) => {
      d1.db.prepare(`
        INSERT INTO recipe_ingredients (
          id, recipe_id, seq, display, name, amount, amount_max, unit, note, tag, is_optional, is_pantry_staple
        ) VALUES (?, ?, ?, ?, ?, 1.0, NULL, 'adet', '', ?, ?, ?)
      `).run(ingSeqId++, r.id, idx + 1, ing.display, ing.name, ing.tag, ing.is_optional ? 1 : 0, ing.is_pantry_staple ? 1 : 0);
    });
  }
}

async function createTestEnv(overrides = {}) {
  resetRecipeCachesForTesting();
  const d1 = new MockD1Database();
  seedSampleRecipes(d1);
  const r2 = new MockR2Bucket();
  r2.putObject('photo_webp_v2/sebze_zeytinyagli/kilerce_karniyarik.webp', new Uint8Array([82, 73, 70, 70, 1, 2, 3]));
  r2.putObject('photo_webp_v2/corba/kilerce_mercimek_corbasi.webp', new Uint8Array([82, 73, 70, 70, 4, 5, 6]));

  return {
    RECIPES_DB: d1,
    RECIPE_MEDIA: r2,
    ORGANIC_SCORE_KV: new MockKVNamespace(),
    HMAC_SECRET: 'test-hmac-secret',
    MEDIA_SIGNING_SECRET: 'test-media-secret',
    REVENUECAT_WEBHOOK_AUTH: 'rc-webhook-secret',
    FREE_DAILY_DETAIL_LIMIT: '5',
    FREE_IP_DAILY_DETAIL_LIMIT: '25',
    REWARD_ADS_REQUIRED: '3',
    REWARD_PRO_HOURS: '3',
    REWARD_DAILY_MAX_PASSES: '2',
    PRO_DAILY_AI_LIMIT: '20',
    SIGNED_MEDIA_TTL_SEC: '900',
    ...overrides,
  };
}

async function signedRequest(pathAndQuery, { method = 'GET', body = '', headers = {}, secret = 'test-hmac-secret', tsOffsetSec = 0 } = {}) {
  const rawUrl = `https://kilerce.example.workers.dev${pathAndQuery}`;
  const parsed = new URL(rawUrl);
  const wirePathAndQuery = `${parsed.pathname}${parsed.search}`;
  const ts = Math.floor(Date.now() / 1000) + tsOffsetSec;
  const canonical = `${ts}.${method.toUpperCase()}.${wirePathAndQuery}.${body}`;
  const sig = await hmacSha256Hex(secret, canonical);
  const reqHeaders = new Headers({
    'X-OrganicScore-Timestamp': String(ts),
    'X-OrganicScore-Signature': sig,
    ...headers,
  });
  return new Request(rawUrl, {
    method,
    headers: reqHeaders,
    body: method === 'POST' ? body : undefined,
  });
}

function p1363ToDer(p1363) {
  const encodeInt = (bytes) => {
    let i = 0;
    while (i < bytes.length - 1 && bytes[i] === 0) i++;
    let slice = bytes.subarray(i);
    if (slice[0] & 0x80) {
      const prefixed = new Uint8Array(slice.length + 1);
      prefixed[0] = 0;
      prefixed.set(slice, 1);
      slice = prefixed;
    }
    const out = new Uint8Array(2 + slice.length);
    out[0] = 0x02;
    out[1] = slice.length;
    out.set(slice, 2);
    return out;
  };
  const r = encodeInt(p1363.subarray(0, 32));
  const s = encodeInt(p1363.subarray(32, 64));
  const der = new Uint8Array(2 + r.length + s.length);
  der[0] = 0x30;
  der[1] = r.length + s.length;
  der.set(r, 2);
  der.set(s, 2 + r.length);
  return der;
}

function toBase64Url(bytes) {
  return Buffer.from(bytes).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

test('health & boycott existing endpoints keep working', async () => {
  const env = await createTestEnv();
  const healthRes = await worker.fetch(new Request('https://kilerce.example.workers.dev/health'), env);
  assert.equal(healthRes.status, 200);
  const healthJson = await healthRes.json();
  assert.equal(healthJson.status, 'ok');

  const boycottRes = await worker.fetch(new Request('https://kilerce.example.workers.dev/api/boycott'), env);
  assert.equal(boycottRes.status, 200);
  const boycottJson = await boycottRes.json();
  assert.ok(Array.isArray(boycottJson) && boycottJson.length >= 10);
});

test('HMAC verification rejects missing, tampered, and expired timestamps', async () => {
  const env = await createTestEnv();
  const noSigRes = await worker.fetch(
    new Request('https://kilerce.example.workers.dev/api/recipes/search?q=karniyarik'),
    env,
  );
  assert.equal(noSigRes.status, 401);

  const expiredReq = await signedRequest('/api/recipes/search?q=karniyarik', { tsOffsetSec: -600 });
  const expiredRes = await worker.fetch(expiredReq, env);
  assert.equal(expiredRes.status, 401);

  const badSigReq = await signedRequest('/api/recipes/search?q=karniyarik', { secret: 'wrong-secret' });
  const badSigRes = await worker.fetch(badSigReq, env);
  assert.equal(badSigRes.status, 401);
});

test('recipes search enforces anti-scraping cap, Turkish FTS, preview-only fields, and signed media proxy', async () => {
  const env = await createTestEnv();
  const req = await signedRequest('/api/recipes/search?q=karnıyarık&limit=200');
  const res = await worker.fetch(req, env);
  assert.equal(res.status, 200);
  const data = await res.json();

  assert.equal(data.limit, 20);
  assert.equal(data.items.length, 1);
  const item = data.items[0];
  assert.equal(item.id, 'kilerce_karniyarik');
  assert.equal('steps' in item, false);
  assert.equal('steps_json' in item, false);
  assert.equal('ingredients' in item, false);
  assert.ok(item.image_url.includes('/api/media/photo_webp_v2/'));

  const mediaRes = await worker.fetch(new Request(item.image_url), env);
  assert.equal(mediaRes.status, 200);
  assert.equal(mediaRes.headers.get('Content-Type'), 'image/webp');
  const bytes = new Uint8Array(await mediaRes.arrayBuffer());
  assert.deepEqual(bytes, new Uint8Array([82, 73, 70, 70, 1, 2, 3]));

  const tamperedMedia = new Request(`${item.image_url}00`);
  const tamperedRes = await worker.fetch(tamperedMedia, env);
  assert.equal(tamperedRes.status, 403);

  const traversalRes = await worker.fetch(
    new Request('https://kilerce.example.workers.dev/api/media/photo_webp_v2/..%2Fsecret.webp?exp=9999999999&sig=abc'),
    env,
  );
  assert.equal(traversalRes.status, 400);
});

test('pantry match ranks matching recipes accurately', async () => {
  const env = await createTestEnv();
  const body = JSON.stringify({
    pantry_tags: ['patlican', 'kiyma', 'domates', 'sogan'],
    expiring_tags: ['kiyma'],
    limit: 50,
  });
  const req = await signedRequest('/api/recipes/match-pantry', {
    method: 'POST',
    body,
    headers: { 'Content-Type': 'application/json' },
  });
  const res = await worker.fetch(req, env);
  assert.equal(res.status, 200);
  const data = await res.json();
  assert.equal(data.limit, 20);
  assert.equal(data.items[0].id, 'kilerce_karniyarik');
  assert.equal(data.items[0].match_ratio, 1);
  assert.deepEqual(data.items[0].expiring_matched_tags, ['kiyma']);
});

test('free users get 5 recipe details per day then HTTP 402 PRO_REQUIRED', async () => {
  const env = await createTestEnv();
  const headers = { 'X-Kilerce-User-Id': 'user_free_1' };

  for (let i = 1; i <= 5; i++) {
    const req = await signedRequest('/api/recipes/kilerce_karniyarik', { headers });
    const res = await worker.fetch(req, env);
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.equal(body.entitlement.daily_detail_used, i);
    assert.equal(body.entitlement.daily_detail_remaining, 5 - i);
    assert.ok(Array.isArray(body.recipe.steps) && body.recipe.steps.length === 2);
  }

  const sixthReq = await signedRequest('/api/recipes/kilerce_karniyarik', { headers });
  const sixthRes = await worker.fetch(sixthReq, env);
  assert.equal(sixthRes.status, 402);
  const sixthBody = await sixthRes.json();
  assert.equal(sixthBody.error, 'PRO_REQUIRED');
  assert.equal(sixthBody.entitlement.daily_detail_remaining, 0);
});

test('AdMob SSV ECDSA verification unlocks 3h Pro twice per day after 3 ads each and blocks 3rd pass + replay', async () => {
  const keyPair = await crypto.subtle.generateKey(
    { name: 'ECDSA', namedCurve: 'P-256' },
    true,
    ['sign', 'verify'],
  );
  const spki = await crypto.subtle.exportKey('spki', keyPair.publicKey);
  const verifierKeys = [{ keyId: 12345, base64: Buffer.from(spki).toString('base64') }];
  const env = await createTestEnv({ ADMOB_VERIFIER_KEYS_OVERRIDE: verifierKeys });

  const callSsv = async (txId, tamper = false) => {
    const unsignedQuery = `ad_network=5450213213286189855&ad_unit=987654321&reward_amount=1&reward_item=pro_step&timestamp=${Date.now()}&transaction_id=${txId}&user_id=user_ads_1`;
    const p1363Sig = new Uint8Array(
      await crypto.subtle.sign(
        { name: 'ECDSA', hash: 'SHA-256' },
        keyPair.privateKey,
        new TextEncoder().encode(unsignedQuery),
      ),
    );
    const der = p1363ToDer(p1363Sig);
    if (tamper) der[der.length - 1] ^= 0xff;
    const fullUrl = `https://kilerce.example.workers.dev/api/webhooks/admob-ssv?${unsignedQuery}&signature=${toBase64Url(der)}&key_id=12345`;
    return worker.fetch(new Request(fullUrl), env);
  };

  const tamperedRes = await callSsv('tx_bad', true);
  assert.equal(tamperedRes.status, 403);

  const ad1 = await (await callSsv('tx_1')).json();
  assert.equal(ad1.entitlement.ad_progress, 1);
  assert.equal(ad1.entitlement.is_pro, false);

  // Replay same transaction_id must not increment progress
  const replay1 = await (await callSsv('tx_1')).json();
  assert.equal(replay1.status, 'duplicate_ignored');
  assert.equal(replay1.entitlement.ad_progress, 1);

  await callSsv('tx_2');
  const ad3 = await (await callSsv('tx_3')).json();
  assert.equal(ad3.entitlement.is_pro, true);
  assert.equal(ad3.entitlement.tier, 'rewarded_pro');
  assert.equal(ad3.entitlement.daily_reward_passes_used, 1);
  assert.equal(ad3.entitlement.daily_reward_passes_limit, 2);
  assert.ok(ad3.entitlement.remaining_pro_seconds > 2 * 3600 && ad3.entitlement.remaining_pro_seconds <= 3 * 3600 + 5);

  // 2nd daily pass (3 more ads -> stacked +3h -> total ~6h)
  await callSsv('tx_4');
  await callSsv('tx_5');
  const ad6 = await (await callSsv('tx_6')).json();
  assert.equal(ad6.entitlement.daily_reward_passes_used, 2);
  assert.ok(ad6.entitlement.remaining_pro_seconds > 5 * 3600);

  // 7th ad same day hits daily 2-pass cap
  const ad7 = await (await callSsv('tx_7')).json();
  assert.equal(ad7.status, 'daily_limit_reached');

  // Pro user bypasses 5/day limit on detail endpoint
  const detailReq = await signedRequest('/api/recipes/kilerce_mercimek_corbasi', {
    headers: { 'X-Kilerce-User-Id': 'user_ads_1' },
  });
  const detailRes = await worker.fetch(detailReq, env);
  assert.equal(detailRes.status, 200);
});

test('POST /api/media/sign-batch signs valid R2 keys and ignores invalid paths', async () => {
  const env = await createTestEnv();
  const body = JSON.stringify({
    paths: [
      'photo_webp_v2/sebze_zeytinyagli/kilerce_karniyarik.webp',
      'photo_webp_v2/../secret.webp',
    ],
  });
  const req = await signedRequest('/api/media/sign-batch', {
    method: 'POST',
    body,
    headers: { 'Content-Type': 'application/json' },
  });
  const res = await worker.fetch(req, env);
  assert.equal(res.status, 200);
  const data = await res.json();
  const signedUrl = data.urls['photo_webp_v2/sebze_zeytinyagli/kilerce_karniyarik.webp'];
  assert.ok(signedUrl && signedUrl.includes('/api/media/photo_webp_v2/'));
  assert.equal('photo_webp_v2/../secret.webp' in data.urls, false);

  const imgRes = await worker.fetch(new Request(signedUrl), env);
  assert.equal(imgRes.status, 200);
});

test('IP daily detail quota limits multi-user free scraping attempts from same IP', async () => {
  const env = await createTestEnv({ FREE_IP_DAILY_DETAIL_LIMIT: '3' });
  for (let i = 1; i <= 3; i++) {
    const req = await signedRequest('/api/recipes/kilerce_karniyarik', {
      headers: { 'X-Kilerce-User-Id': `alt_user_${i}`, 'CF-Connecting-IP': '1.2.3.4' },
    });
    const res = await worker.fetch(req, env);
    assert.equal(res.status, 200);
  }
  const blockedReq = await signedRequest('/api/recipes/kilerce_karniyarik', {
    headers: { 'X-Kilerce-User-Id': 'alt_user_4', 'CF-Connecting-IP': '1.2.3.4' },
  });
  const blockedRes = await worker.fetch(blockedReq, env);
  assert.equal(blockedRes.status, 429);
});

test('RevenueCat webhook authorizes Bearer token, handles yearly & lifetime, and protects lifetime on expiration', async () => {
  const env = await createTestEnv();

  const unauthRes = await worker.fetch(
    new Request('https://kilerce.example.workers.dev/api/webhooks/revenuecat', {
      method: 'POST',
      headers: { Authorization: 'Bearer wrong-token', 'Content-Type': 'application/json' },
      body: JSON.stringify({ event: { id: 'e0', app_user_id: 'u1', type: 'INITIAL_PURCHASE' } }),
    }),
    env,
  );
  assert.equal(unauthRes.status, 401);

  const postRc = async (event) =>
    worker.fetch(
      new Request('https://kilerce.example.workers.dev/api/webhooks/revenuecat', {
        method: 'POST',
        headers: {
          Authorization: 'Bearer rc-webhook-secret',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ event }),
      }),
      env,
    );

  const futureMs = Date.now() + 365 * 24 * 3600 * 1000;
  const yearlyRes = await (
    await postRc({
      id: 'rc_evt_1',
      app_user_id: 'user_rc_1',
      type: 'INITIAL_PURCHASE',
      product_id: 'kilerce_pro_yearly',
      expiration_at_ms: futureMs,
    })
  ).json();
  assert.equal(yearlyRes.entitlement.is_pro, true);
  assert.equal(yearlyRes.entitlement.tier, 'yearly');
  assert.equal(yearlyRes.entitlement.is_lifetime, false);

  const expiredRes = await (
    await postRc({
      id: 'rc_evt_2',
      app_user_id: 'user_rc_1',
      type: 'EXPIRATION',
      product_id: 'kilerce_pro_yearly',
    })
  ).json();
  assert.equal(expiredRes.entitlement.is_pro, false);
  assert.equal(expiredRes.entitlement.tier, 'free');

  const lifetimeRes = await (
    await postRc({
      id: 'rc_evt_3',
      app_user_id: 'user_rc_lifetime',
      type: 'NON_RENEWING_PURCHASE',
      product_id: 'kilerce_pro_lifetime',
    })
  ).json();
  assert.equal(lifetimeRes.entitlement.is_pro, true);
  assert.equal(lifetimeRes.entitlement.is_lifetime, true);
  assert.equal(lifetimeRes.entitlement.tier, 'lifetime');

  const expiredLifetimeRes = await (
    await postRc({
      id: 'rc_evt_4',
      app_user_id: 'user_rc_lifetime',
      type: 'EXPIRATION',
      product_id: 'kilerce_pro_monthly',
    })
  ).json();
  assert.equal(expiredLifetimeRes.entitlement.is_pro, true);
  assert.equal(expiredLifetimeRes.entitlement.is_lifetime, true);
});

test('KV PUT 429 rate-limit errors never trigger HTTP 500 on recipe detail, health, or media bursts', async () => {
  const failingKv = {
    async get() {
      return null;
    },
    async put() {
      throw new Error('KV PUT failed: 429 Too Many Requests');
    },
  };
  const env = await createTestEnv({ ORGANIC_SCORE_KV: failingKv });

  // Parallel burst on /health must all succeed
  const healthBurst = await Promise.all(
    Array.from({ length: 12 }, () =>
      worker.fetch(new Request('https://kilerce.example.workers.dev/health'), env),
    ),
  );
  assert.ok(healthBurst.every((res) => res.status === 200));

  // Recipe detail with failing KV.put must return 200, never 500
  const detailReq = await signedRequest('/api/recipes/kilerce_karniyarik', {
    headers: { 'X-Kilerce-User-Id': 'user_kv_resilient', 'CF-Connecting-IP': '9.9.9.9' },
  });
  const detailRes = await worker.fetch(detailReq, env);
  assert.equal(detailRes.status, 200);
  const detailBody = await detailRes.json();
  assert.equal(detailBody.recipe.id, 'kilerce_karniyarik');

  // Signed media burst must also succeed with 200
  const mediaBurst = await Promise.all(
    Array.from({ length: 12 }, () => worker.fetch(new Request(detailBody.recipe.image_url), env)),
  );
  assert.ok(mediaBurst.every((res) => res.status === 200));
});

test('POST /api/entitlements/redeem-promo activates TESTER2026 in D1 and unlocks recipes past 5/day limit', async () => {
  const env = await createTestEnv();
  const headers = { 'X-Kilerce-User-Id': 'user_tester_cloud_1' };

  // Exhaust 5 free details
  for (let i = 0; i < 5; i++) {
    const res = await worker.fetch(
      await signedRequest('/api/recipes/kilerce_karniyarik', { headers }),
      env,
    );
    assert.equal(res.status, 200);
  }
  const blockedRes = await worker.fetch(
    await signedRequest('/api/recipes/kilerce_karniyarik', { headers }),
    env,
  );
  assert.equal(blockedRes.status, 402);

  // Invalid promo returns 400
  const badPromoRes = await worker.fetch(
    await signedRequest('/api/entitlements/redeem-promo', {
      method: 'POST',
      body: JSON.stringify({ code: 'INVALID_CODE' }),
      headers: { ...headers, 'Content-Type': 'application/json' },
    }),
    env,
  );
  assert.equal(badPromoRes.status, 400);

  // Valid TESTER2026 activates tester Pro in D1
  const okPromoRes = await worker.fetch(
    await signedRequest('/api/entitlements/redeem-promo', {
      method: 'POST',
      body: JSON.stringify({ code: 'TESTER2026' }),
      headers: { ...headers, 'Content-Type': 'application/json' },
    }),
    env,
  );
  assert.equal(okPromoRes.status, 200);
  const promoBody = await okPromoRes.json();
  assert.equal(promoBody.entitlement.is_pro, true);
  assert.equal(promoBody.entitlement.tier, 'tester');

  // Recipe detail now returns 200
  const unlockedRes = await worker.fetch(
    await signedRequest('/api/recipes/kilerce_mercimek_corbasi', { headers }),
    env,
  );
  assert.equal(unlockedRes.status, 200);
});

test('POST /api/entitlements/reward-ad-step unlocks 3h Pro after 3 ads in D1 and caps at 2 passes/day', async () => {
  const env = await createTestEnv();
  const headers = { 'X-Kilerce-User-Id': 'user_reward_client_1', 'Content-Type': 'application/json' };

  // Exhaust 5 free details first
  for (let i = 0; i < 5; i++) {
    await worker.fetch(await signedRequest('/api/recipes/kilerce_karniyarik', { headers: { 'X-Kilerce-User-Id': 'user_reward_client_1' } }), env);
  }

  const step1 = await (await worker.fetch(await signedRequest('/api/entitlements/reward-ad-step', { method: 'POST', body: '{}', headers }), env)).json();
  assert.equal(step1.entitlement.ad_progress, 1);
  assert.equal(step1.unlocked_pro_3h, false);

  const step2 = await (await worker.fetch(await signedRequest('/api/entitlements/reward-ad-step', { method: 'POST', body: '{}', headers }), env)).json();
  assert.equal(step2.entitlement.ad_progress, 2);
  assert.equal(step2.unlocked_pro_3h, false);

  const step3 = await (await worker.fetch(await signedRequest('/api/entitlements/reward-ad-step', { method: 'POST', body: '{}', headers }), env)).json();
  assert.equal(step3.unlocked_pro_3h, true);
  assert.equal(step3.entitlement.is_pro, true);
  assert.equal(step3.entitlement.daily_reward_passes_used, 1);

  // Recipe detail is now unlocked
  const unlockedRes = await worker.fetch(
    await signedRequest('/api/recipes/kilerce_mercimek_corbasi', { headers: { 'X-Kilerce-User-Id': 'user_reward_client_1' } }),
    env,
  );
  assert.equal(unlockedRes.status, 200);

  // 2nd daily pass (3 more ads)
  await worker.fetch(await signedRequest('/api/entitlements/reward-ad-step', { method: 'POST', body: '{}', headers }), env);
  await worker.fetch(await signedRequest('/api/entitlements/reward-ad-step', { method: 'POST', body: '{}', headers }), env);
  const step6 = await (await worker.fetch(await signedRequest('/api/entitlements/reward-ad-step', { method: 'POST', body: '{}', headers }), env)).json();
  assert.equal(step6.entitlement.daily_reward_passes_used, 2);

  // 7th ad hits daily cap
  const step7 = await (await worker.fetch(await signedRequest('/api/entitlements/reward-ad-step', { method: 'POST', body: '{}', headers }), env)).json();
  assert.equal(step7.status, 'daily_limit_reached');
  assert.equal(step7.unlocked_pro_3h, false);
});

test('D1 daily write limit errors fall back cleanly to KV/memory without HTTP 500', async () => {
  const env = await createTestEnv();
  const baseDb = env.RECIPES_DB;
  env.RECIPES_DB = {
    prepare(sql) {
      const stmt = baseDb.prepare(sql);
      const wrapStmt = (s) => ({
        bind(...args) {
          return wrapStmt(s.bind(...args));
        },
        first() {
          return s.first();
        },
        all() {
          return s.all();
        },
        async run() {
          throw new Error("D1_ERROR: Your account has exceeded D1's free tier daily row write limit.");
        },
      });
      return wrapStmt(stmt);
    },
  };

  // Free recipe detail must succeed with 200 even if D1 writes fail
  const detailRes = await worker.fetch(
    await signedRequest('/api/recipes/kilerce_karniyarik', {
      headers: { 'X-Kilerce-User-Id': 'user_d1_write_fail_1' },
    }),
    env,
  );
  assert.equal(detailRes.status, 200);

  // Promo redemption must succeed and persist to KV
  const promoRes = await worker.fetch(
    await signedRequest('/api/entitlements/redeem-promo', {
      method: 'POST',
      body: JSON.stringify({ code: 'TESTER2026' }),
      headers: {
        'X-Kilerce-User-Id': 'user_d1_write_fail_promo',
        'Content-Type': 'application/json',
      },
    }),
    env,
  );
  assert.equal(promoRes.status, 200);
  const promoBody = await promoRes.json();
  assert.equal(promoBody.entitlement.is_pro, true);
  assert.ok(await env.ORGANIC_SCORE_KV.get('ent:user_d1_write_fail_promo'));

  // Subsequent /api/entitlements/me must return Pro
  const meRes = await worker.fetch(
    await signedRequest('/api/entitlements/me', {
      headers: { 'X-Kilerce-User-Id': 'user_d1_write_fail_promo' },
    }),
    env,
  );
  assert.equal(meRes.status, 200);
  assert.equal((await meRes.json()).entitlement.is_pro, true);

  // 3x rewarded ad steps must all return 200 and unlock Pro in KV
  const adHeaders = {
    'X-Kilerce-User-Id': 'user_d1_write_fail_ads',
    'Content-Type': 'application/json',
  };
  for (let i = 1; i <= 3; i++) {
    const r = await worker.fetch(
      await signedRequest('/api/entitlements/reward-ad-step', {
        method: 'POST',
        body: '{}',
        headers: adHeaders,
      }),
      env,
    );
    assert.equal(r.status, 200);
    const body = await r.json();
    if (i < 3) {
      assert.equal(body.entitlement.ad_progress, i);
      assert.equal(body.entitlement.is_pro, false);
    } else {
      assert.equal(body.unlocked_pro_3h, true);
      assert.equal(body.entitlement.is_pro, true);
    }
  }
  assert.ok(await env.ORGANIC_SCORE_KV.get('ent:user_d1_write_fail_ads'));
});

test('Gemini 2.5 Flash-Lite OCR endpoints enforce HMAC, disable thinking tokens, cache repeats, and enforce daily quota', async () => {
  const originalFetch = globalThis.fetch;
  let geminiCalls = 0;
  let lastRequestBody = null;
  let lastUrl = '';

  globalThis.fetch = async (url, init) => {
    geminiCalls += 1;
    lastUrl = String(url);
    lastRequestBody = JSON.parse(init.body);
    if (lastRequestBody.contents[0].parts[0].text.includes('market fişi')) {
      return new Response(
        JSON.stringify({
          candidates: [
            {
              content: {
                parts: [
                  {
                    text: JSON.stringify({
                      items: [
                        {
                          name: 'Yarım Yağlı Süt',
                          raw_line: 'YRM YAG SUT 1L',
                          unit_label: '1 Lt',
                          storage_zone: 'FRIDGE',
                        },
                      ],
                    }),
                  },
                ],
              },
            },
          ],
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      );
    }

    return new Response(
      JSON.stringify({
        candidates: [
          {
            content: {
              parts: [
                {
                  text: JSON.stringify({
                    brand: 'Torku',
                    product_name: 'Tam Buğdaylı Bisküvi',
                    net_quantity: '131 g',
                    ingredients_text: 'Tam buğday unu, bitkisel yağ, şeker',
                    allergens: ['Gluten'],
                  }),
                },
              ],
            },
          },
        ],
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } },
    );
  };

  try {
    // 1. Missing GEMINI_API_KEY returns 503 for clean client fallback
    const envNoKey = await createTestEnv();
    const resNoKey = await worker.fetch(
      await signedRequest('/api/ocr/receipt', {
        method: 'POST',
        body: JSON.stringify({ image_base64: 'YWJjZA==' }),
        headers: { 'Content-Type': 'application/json', 'X-Kilerce-User-Id': 'ocr_user_1' },
      }),
      envNoKey,
    );
    assert.equal(resNoKey.status, 503);
    assert.equal((await resNoKey.json()).error, 'GEMINI_NOT_CONFIGURED');

    // 2. Receipt OCR calls gemini-2.5-flash-lite with thinkingBudget: 0
    const env = await createTestEnv({
      GEMINI_API_KEY: 'test-gemini-key',
      OCR_DAILY_LIMIT: '2',
    });
    const receiptBody = JSON.stringify({ image_base64: 'aW1hZ2Ux', mime_type: 'image/jpeg' });
    const receiptRes1 = await worker.fetch(
      await signedRequest('/api/ocr/receipt', {
        method: 'POST',
        body: receiptBody,
        headers: { 'Content-Type': 'application/json', 'X-Kilerce-User-Id': 'ocr_user_1' },
      }),
      env,
    );
    assert.equal(receiptRes1.status, 200);
    const r1Json = await receiptRes1.json();
    assert.equal(r1Json.cached, false);
    assert.equal(r1Json.items.length, 1);
    assert.equal(r1Json.items[0].name, 'Yarım Yağlı Süt');
    assert.equal(r1Json.items[0].storage_zone, 'FRIDGE');
    assert.ok(lastUrl.includes('gemini-3.5-flash-lite'));
    assert.equal(lastRequestBody.generationConfig.thinkingConfig.thinkingLevel, 'minimal');
    assert.equal(geminiCalls, 1);

    // 3. Identical image hits KV dedup cache with 0 extra Gemini calls
    const receiptRes2 = await worker.fetch(
      await signedRequest('/api/ocr/receipt', {
        method: 'POST',
        body: receiptBody,
        headers: { 'Content-Type': 'application/json', 'X-Kilerce-User-Id': 'ocr_user_1' },
      }),
      env,
    );
    assert.equal(receiptRes2.status, 200);
    assert.equal((await receiptRes2.json()).cached, true);
    assert.equal(geminiCalls, 1);

    // 4. Product label OCR extracts structured fields
    const labelRes = await worker.fetch(
      await signedRequest('/api/ocr/product-label', {
        method: 'POST',
        body: JSON.stringify({ image_base64: 'bGFiZWwx', mode: 'AUTO' }),
        headers: { 'Content-Type': 'application/json', 'X-Kilerce-User-Id': 'ocr_user_1' },
      }),
      env,
    );
    assert.equal(labelRes.status, 200);
    const labelJson = await labelRes.json();
    assert.equal(labelJson.brand, 'Torku');
    assert.equal(labelJson.product_name, 'Tam Buğdaylı Bisküvi');
    assert.equal(labelJson.net_quantity, '131 g');
    assert.deepEqual(labelJson.allergens, ['Gluten']);
    assert.equal(geminiCalls, 2);

    // 5. 3rd non-cached call for ocr_user_1 hits OCR_DAILY_LIMIT=2 -> 429
    const quotaRes = await worker.fetch(
      await signedRequest('/api/ocr/product-label', {
        method: 'POST',
        body: JSON.stringify({ image_base64: 'bGFiZWwy', mode: 'INGREDIENTS' }),
        headers: { 'Content-Type': 'application/json', 'X-Kilerce-User-Id': 'ocr_user_1' },
      }),
      env,
    );
    assert.equal(quotaRes.status, 429);
    assert.equal((await quotaRes.json()).error, 'OCR_DAILY_LIMIT_EXCEEDED');
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('match-pantry caches raw D1 candidates across tag order, offset, and expiring_tags while refreshing signed URLs', async () => {
  const env = await createTestEnv();
  let dbAllCalls = 0;
  const baseDb = env.RECIPES_DB;
  env.RECIPES_DB = {
    prepare(sql) {
      const stmt = baseDb.prepare(sql);
      const wrapStmt = (s) => ({
        bind(...args) {
          return wrapStmt(s.bind(...args));
        },
        first() {
          return s.first();
        },
        async all() {
          dbAllCalls += 1;
          return s.all();
        },
        run() {
          return s.run();
        },
      });
      return wrapStmt(stmt);
    },
  };

  const req1 = await signedRequest('/api/recipes/match-pantry', {
    method: 'POST',
    body: JSON.stringify({
      pantry_tags: ['sogan', 'domates', 'kiyma', 'patlican'],
      expiring_tags: ['kiyma'],
      limit: 1,
      offset: 0,
    }),
    headers: { 'Content-Type': 'application/json' },
  });
  const res1 = await worker.fetch(req1, env);
  assert.equal(res1.status, 200);
  assert.equal(res1.headers.get('X-Kilerce-Cache'), 'MISS');
  const data1 = await res1.json();
  assert.equal(data1.items.length, 1);
  assert.equal(data1.items[0].id, 'kilerce_karniyarik');
  assert.deepEqual(data1.items[0].expiring_matched_tags, ['kiyma']);
  assert.ok(data1.items[0].image_url.includes('/api/media/'));
  assert.equal(dbAllCalls, 1);

  const req2 = await signedRequest('/api/recipes/match-pantry', {
    method: 'POST',
    body: JSON.stringify({
      pantry_tags: ['patlican', 'kiyma', 'domates', 'sogan'],
      expiring_tags: ['patlican'],
      limit: 1,
      offset: 1,
    }),
    headers: { 'Content-Type': 'application/json' },
  });
  const res2 = await worker.fetch(req2, env);
  assert.equal(res2.status, 200);
  assert.equal(res2.headers.get('X-Kilerce-Cache'), 'HIT-MEM');
  const data2 = await res2.json();
  assert.equal(data2.items.length, 1);
  assert.equal(data2.items[0].id, 'kilerce_mercimek_corbasi');
  assert.ok(data2.items[0].image_url.includes('/api/media/'));
  assert.equal(dbAllCalls, 1);
});

test('match-pantry excludes high-frequency staple tags from SQL when selective tags exist, and falls back when only staples exist', async () => {
  const env = await createTestEnv();
  const capturedBinds = [];
  const baseDb = env.RECIPES_DB;
  env.RECIPES_DB = {
    prepare(sql) {
      const stmt = baseDb.prepare(sql);
      const wrapStmt = (s, bound = []) => ({
        bind(...args) {
          return wrapStmt(s.bind(...args), args);
        },
        first() {
          return s.first();
        },
        async all() {
          capturedBinds.push(bound);
          return s.all();
        },
        run() {
          return s.run();
        },
      });
      return wrapStmt(stmt);
    },
  };

  // Seed a recipe with only staple ingredients for fallback verification
  baseDb.db.prepare(`
    INSERT INTO recipes (
      id, source, title, subtitle, emoji, category, kilerce_category, region_id,
      prep_minutes, cook_minutes, total_minutes, servings_count, servings_unit, servings_label,
      difficulty, cooking_method, contains_gluten, contains_lactose, is_vegan, is_vegetarian,
      has_margarine, is_refined_sugar_free, is_healthy_clean, base_health_score, quality_score,
      clean_label_badges_json, diet_tags_json, meal_slots_json, required_tags_json, optional_tags_json,
      ingredients_json, steps_json, image_rel_path, search_fold
    ) VALUES (
      'kilerce_un_helvasi', 'yemek_com', 'Un Helvası', 'Tatlı', '🍮', 'Tatlı', 'Tatlı', 'tum_turkiye',
      5, 15, 20, 4, 'kisilik', '4 kişilik', 'easy', 'pan',
      1, 1, 0, 1, 0, 0, 0, 70, 88,
      '["Ev Yapımı"]', '[]', '["DESSERT"]', '["un","tereyagi"]', '[]',
      '[]', '["Unu kavurun."]', 'photo_webp_v2/tatli/kilerce_un_helvasi.webp', 'un helvasi'
    )
  `).run();
  baseDb.db.prepare(`
    INSERT INTO recipe_ingredients (id, recipe_id, seq, display, name, amount, amount_max, unit, note, tag, is_optional, is_pantry_staple)
    VALUES (1001, 'kilerce_un_helvasi', 1, '2 su bardağı un', 'un', 2, NULL, 'bardak', '', 'un', 0, 1),
           (1002, 'kilerce_un_helvasi', 2, '100 g tereyağı', 'tereyagi', 100, NULL, 'gr', '', 'tereyagi', 0, 1)
  `).run();

  // Case 1: selective + staple tags -> staples excluded from SQL binds
  const selectiveReq = await signedRequest('/api/recipes/match-pantry', {
    method: 'POST',
    body: JSON.stringify({
      pantry_tags: ['patlican', 'kiyma', 'un', 'tereyagi', 'zeytinyagi'],
    }),
    headers: { 'Content-Type': 'application/json' },
  });
  const selectiveRes = await worker.fetch(selectiveReq, env);
  assert.equal(selectiveRes.status, 200);
  const selectiveData = await selectiveRes.json();
  assert.equal(selectiveData.items[0].id, 'kilerce_karniyarik');
  assert.deepEqual(capturedBinds[0], ['kiyma', 'patlican']);

  // Case 2: only staple tags -> falls back to querying staple tags
  const stapleOnlyReq = await signedRequest('/api/recipes/match-pantry', {
    method: 'POST',
    body: JSON.stringify({
      pantry_tags: ['un', 'tereyagi'],
    }),
    headers: { 'Content-Type': 'application/json' },
  });
  const stapleOnlyRes = await worker.fetch(stapleOnlyReq, env);
  assert.equal(stapleOnlyRes.status, 200);
  const stapleOnlyData = await stapleOnlyRes.json();
  assert.equal(stapleOnlyData.items[0].id, 'kilerce_un_helvasi');
  assert.deepEqual(capturedBinds[1], ['tereyagi', 'un']);
});

test('recipes search caches raw D1 results across repeated queries and serves HIT-MEM with fresh signed URLs', async () => {
  const env = await createTestEnv();
  let dbAllCalls = 0;
  const baseDb = env.RECIPES_DB;
  env.RECIPES_DB = {
    prepare(sql) {
      const stmt = baseDb.prepare(sql);
      const wrapStmt = (s) => ({
        bind(...args) {
          return wrapStmt(s.bind(...args));
        },
        first() {
          return s.first();
        },
        async all() {
          dbAllCalls += 1;
          return s.all();
        },
        run() {
          return s.run();
        },
      });
      return wrapStmt(stmt);
    },
  };

  const res1 = await worker.fetch(await signedRequest('/api/recipes/search?q=karnıyarık&limit=10'), env);
  assert.equal(res1.status, 200);
  assert.equal(res1.headers.get('X-Kilerce-Cache'), 'MISS');
  const data1 = await res1.json();
  assert.equal(data1.items.length, 1);
  assert.ok(data1.items[0].image_url.includes('/api/media/'));
  assert.equal(dbAllCalls, 1);

  const res2 = await worker.fetch(await signedRequest('/api/recipes/search?q=karnıyarık&limit=10'), env);
  assert.equal(res2.status, 200);
  assert.equal(res2.headers.get('X-Kilerce-Cache'), 'HIT-MEM');
  const data2 = await res2.json();
  assert.equal(data2.items.length, 1);
  assert.ok(data2.items[0].image_url.includes('/api/media/'));
  assert.equal(dbAllCalls, 1);
});
