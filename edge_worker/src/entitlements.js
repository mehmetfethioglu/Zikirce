import { constantTimeEqual, jsonResponse, safeJsonParse } from './security.js';

const ADMOB_VERIFIER_KEYS_URL = 'https://www.gstatic.com/admob/reward/verifier-keys.json';
const ADMOB_KEYS_KV_CACHE_KEY = 'admob:ssv:verifier_keys_v1';
const HOUR_MS = 3600 * 1000;
const MAX_IP_DETAIL_ENTRIES = 2000;

const TESTER_PROMO_CODES = new Set(['TESTER2026', 'KAPALI2026', 'KILERCE_TESTER']);
const CAMPAIGN_PROMO_CODES = new Set(['KILERCE2026', 'KILERCE3GUN', 'TEMIZMUTFAK']);

const _inMemoryIpDetailCounts = new Map();
const _inMemoryEntitlements = new Map();
const MAX_MEM_ENTITLEMENTS = 2000;
const KV_ENTITLEMENT_PREFIX = 'ent:';

function normalizeEntitlementRecord(appUserId, raw) {
  return {
    app_user_id: appUserId,
    tier: raw?.tier || 'free',
    source: raw?.source || 'none',
    pro_until_ms: Number(raw?.pro_until_ms) || 0,
    is_lifetime: raw?.is_lifetime ? 1 : 0,
    ad_progress_count: Number(raw?.ad_progress_count) || 0,
    ad_window_reset_ms: Number(raw?.ad_window_reset_ms) || 0,
    last_ad_reward_ms: Number(raw?.last_ad_reward_ms) || 0,
    daily_detail_date: String(raw?.daily_detail_date || ''),
    daily_detail_used: Number(raw?.daily_detail_used) || 0,
    reward_passes_date: String(raw?.reward_passes_date || ''),
    reward_passes_today: Number(raw?.reward_passes_today) || 0,
    updated_at_ms: Number(raw?.updated_at_ms) || 0,
  };
}

async function readEntitlementRecord(env, appUserId) {
  if (!appUserId) return null;
  const candidates = [];

  if (env.RECIPES_DB) {
    try {
      const d1Row = await env.RECIPES_DB
        .prepare('SELECT * FROM user_entitlements WHERE app_user_id = ?')
        .bind(appUserId)
        .first();
      if (d1Row) candidates.push(d1Row);
    } catch {
      // Fall back to KV / in-memory record if D1 read fails
    }
  }

  if (env.ORGANIC_SCORE_KV) {
    try {
      const kvRaw = await env.ORGANIC_SCORE_KV.get(`${KV_ENTITLEMENT_PREFIX}${appUserId}`);
      const kvParsed = kvRaw ? safeJsonParse(kvRaw) : null;
      if (kvParsed && typeof kvParsed === 'object') {
        candidates.push(kvParsed);
      }
    } catch {
      // Ignore KV read error
    }
  }

  const memRow = _inMemoryEntitlements.get(appUserId);
  if (memRow) {
    candidates.push(memRow);
  }

  if (candidates.length === 0) return null;

  let latest = candidates[0];
  let maxUpdated = Number(latest.updated_at_ms) || 0;
  let maxProUntil = Number(latest.pro_until_ms) || 0;
  let anyLifetime = Boolean(latest.is_lifetime);

  for (let i = 1; i < candidates.length; i++) {
    const c = candidates[i];
    const upd = Number(c.updated_at_ms) || 0;
    if (upd >= maxUpdated) {
      maxUpdated = upd;
      latest = c;
    }
    const proUntil = Number(c.pro_until_ms) || 0;
    if (proUntil > maxProUntil) {
      maxProUntil = proUntil;
    }
    if (c.is_lifetime) {
      anyLifetime = true;
    }
  }

  const merged = normalizeEntitlementRecord(appUserId, latest);
  merged.pro_until_ms = maxProUntil;
  if (anyLifetime) {
    merged.is_lifetime = 1;
    merged.tier = 'lifetime';
  }
  return merged;
}

async function persistEntitlementRecord(env, rawRecord, { fallbackToKv = true } = {}) {
  const record = normalizeEntitlementRecord(rawRecord.app_user_id, rawRecord);

  if (_inMemoryEntitlements.size >= MAX_MEM_ENTITLEMENTS) {
    const oldestKey = _inMemoryEntitlements.keys().next().value;
    if (oldestKey !== undefined) {
      _inMemoryEntitlements.delete(oldestKey);
    }
  }
  _inMemoryEntitlements.set(record.app_user_id, record);

  let d1Persisted = false;
  if (env.RECIPES_DB) {
    try {
      await env.RECIPES_DB
        .prepare(`
          INSERT INTO user_entitlements (
            app_user_id, tier, source, pro_until_ms, is_lifetime,
            ad_progress_count, ad_window_reset_ms, last_ad_reward_ms,
            daily_detail_date, daily_detail_used,
            reward_passes_date, reward_passes_today, updated_at_ms
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT(app_user_id) DO UPDATE SET
            tier = excluded.tier,
            source = excluded.source,
            pro_until_ms = excluded.pro_until_ms,
            is_lifetime = excluded.is_lifetime,
            ad_progress_count = excluded.ad_progress_count,
            ad_window_reset_ms = excluded.ad_window_reset_ms,
            last_ad_reward_ms = excluded.last_ad_reward_ms,
            daily_detail_date = excluded.daily_detail_date,
            daily_detail_used = excluded.daily_detail_used,
            reward_passes_date = excluded.reward_passes_date,
            reward_passes_today = excluded.reward_passes_today,
            updated_at_ms = excluded.updated_at_ms
        `)
        .bind(
          record.app_user_id,
          record.tier,
          record.source,
          record.pro_until_ms,
          record.is_lifetime,
          record.ad_progress_count,
          record.ad_window_reset_ms,
          record.last_ad_reward_ms,
          record.daily_detail_date,
          record.daily_detail_used,
          record.reward_passes_date,
          record.reward_passes_today,
          record.updated_at_ms,
        )
        .run();
      d1Persisted = true;
    } catch {
      d1Persisted = false;
    }
  }

  if (!d1Persisted && fallbackToKv && env.ORGANIC_SCORE_KV) {
    try {
      await env.ORGANIC_SCORE_KV.put(
        `${KV_ENTITLEMENT_PREFIX}${record.app_user_id}`,
        JSON.stringify(record),
      );
    } catch {
      // Best-effort KV fallback; in-memory isolate copy still remains active
    }
  }

  return record;
}

function envNumber(env, key, fallback) {
  const n = Number(env?.[key]);
  return Number.isFinite(n) && n > 0 ? n : fallback;
}

export function extractAppUserId(request) {
  const raw = (request.headers.get('X-Kilerce-User-Id') || '').trim();
  if (!raw || raw.length > 128) return null;
  if (!/^[a-zA-Z0-9._:@-]+$/.test(raw)) return null;
  return raw;
}

export function utcDateString(nowMs = Date.now()) {
  return new Date(nowMs).toISOString().slice(0, 10);
}

export async function resolveEntitlement(env, appUserId, nowMs = Date.now()) {
  const dailyLimit = envNumber(env, 'FREE_DAILY_DETAIL_LIMIT', 5);
  const adsRequired = envNumber(env, 'REWARD_ADS_REQUIRED', 3);
  const maxDailyPasses = envNumber(env, 'REWARD_DAILY_MAX_PASSES', 2);
  const today = utcDateString(nowMs);

  const row = await readEntitlementRecord(env, appUserId);

  const isLifetime = Boolean(row?.is_lifetime);
  const proUntilMs = Number(row?.pro_until_ms) || 0;
  const hasTimedPro = proUntilMs > nowMs;
  const isPro = isLifetime || hasTimedPro;

  let tier = 'free';
  if (isLifetime) {
    tier = 'lifetime';
  } else if (hasTimedPro) {
    tier = row?.tier && row.tier !== 'free' ? row.tier : 'pro';
  }

  const resetMs = Number(row?.ad_window_reset_ms) || 0;
  const adProgress = (!row || (resetMs > 0 && resetMs <= nowMs))
    ? 0
    : Math.min(adsRequired, Number(row.ad_progress_count) || 0);

  const dailyUsed = (row && row.daily_detail_date === today)
    ? (Number(row.daily_detail_used) || 0)
    : 0;
  const dailyRemaining = isPro ? dailyLimit : Math.max(0, dailyLimit - dailyUsed);
  const dailyPassesUsed = (row && row.reward_passes_date === today)
    ? (Number(row.reward_passes_today) || 0)
    : 0;

  return {
    app_user_id: appUserId,
    is_pro: isPro,
    tier,
    source: isPro ? (row?.source || 'none') : 'none',
    is_lifetime: isLifetime,
    pro_until_ms: isLifetime ? 0 : (hasTimedPro ? proUntilMs : 0),
    remaining_pro_seconds: isLifetime
      ? null
      : (hasTimedPro ? Math.max(0, Math.floor((proUntilMs - nowMs) / 1000)) : 0),
    ad_progress: adProgress,
    ads_required: adsRequired,
    daily_reward_passes_used: dailyPassesUsed,
    daily_reward_passes_limit: maxDailyPasses,
    daily_detail_used: dailyUsed,
    daily_detail_limit: dailyLimit,
    daily_detail_remaining: dailyRemaining,
  };
}

export async function consumeIpFreeDetailQuota(env, request, nowMs = Date.now()) {
  const limit = envNumber(env, 'FREE_IP_DAILY_DETAIL_LIMIT', 25);
  const ip = request.headers.get('CF-Connecting-IP') || 'unknown';
  const today = utcDateString(nowMs);
  const key = `ip_detail:${ip}:${today}`;

  if (_inMemoryIpDetailCounts.size > MAX_IP_DETAIL_ENTRIES) {
    for (const [entryKey, entry] of _inMemoryIpDetailCounts.entries()) {
      if (entry.today !== today) {
        _inMemoryIpDetailCounts.delete(entryKey);
      }
    }
    if (_inMemoryIpDetailCounts.size > MAX_IP_DETAIL_ENTRIES) {
      _inMemoryIpDetailCounts.clear();
    }
  }

  let kvCount = 0;
  if (env.ORGANIC_SCORE_KV) {
    try {
      const raw = await env.ORGANIC_SCORE_KV.get(key);
      kvCount = raw ? Number(raw) || 0 : 0;
    } catch {
      kvCount = 0;
    }
  }

  const memCount = _inMemoryIpDetailCounts.get(key)?.count || 0;
  const current = Math.max(kvCount, memCount);
  if (current >= limit) {
    return { allowed: false, used: current, limit };
  }

  const nextUsed = current + 1;
  _inMemoryIpDetailCounts.set(key, { today, count: nextUsed });

  if (env.ORGANIC_SCORE_KV) {
    try {
      await env.ORGANIC_SCORE_KV.put(key, String(nextUsed), {
        expirationTtl: 86400,
      });
    } catch {
      // Best-effort KV sync; Cloudflare KV 1-write/sec or daily limit must never trigger HTTP 500
    }
  }

  return { allowed: true, used: nextUsed, limit };
}

export async function consumeFreeDetailQuota(env, appUserId, nowMs = Date.now()) {
  const limit = envNumber(env, 'FREE_DAILY_DETAIL_LIMIT', 5);
  const today = utcDateString(nowMs);
  if (!env.RECIPES_DB) {
    return { allowed: true, used: 0, limit };
  }

  const existing = await readEntitlementRecord(env, appUserId);
  const currentUsed = existing && existing.daily_detail_date === today
    ? (Number(existing.daily_detail_used) || 0)
    : 0;
  if (currentUsed >= limit) {
    return { allowed: false, used: currentUsed, limit };
  }

  const nextUsed = currentUsed + 1;
  const base = normalizeEntitlementRecord(appUserId, existing);
  base.daily_detail_date = today;
  base.daily_detail_used = nextUsed;
  base.updated_at_ms = nowMs;

  await persistEntitlementRecord(env, base, { fallbackToKv: false });
  return { allowed: true, used: nextUsed, limit };
}

export async function handleGetEntitlement(request, env, corsHeaders) {
  const appUserId = extractAppUserId(request);
  if (!appUserId) {
    return jsonResponse({ error: 'Missing or invalid X-Kilerce-User-Id header' }, 400, corsHeaders);
  }
  const entitlement = await resolveEntitlement(env, appUserId, Date.now());
  return jsonResponse({ entitlement }, 200, corsHeaders);
}

function classifySubscriptionTier(productId) {
  const p = String(productId || '').toLowerCase();
  if (p.includes('lifetime') || p.includes('omur')) return 'lifetime';
  if (p.includes('year') || p.includes('annual') || p.includes('yillik')) return 'yearly';
  if (p.includes('month') || p.includes('aylik')) return 'monthly';
  if (p.includes('week') || p.includes('hafta')) return 'weekly';
  return 'pro';
}

export async function handleRevenueCatWebhook(request, env, corsHeaders, rawBody) {
  const expectedSecret = (env.REVENUECAT_WEBHOOK_AUTH || '').trim();
  if (!expectedSecret) {
    return jsonResponse({ error: 'Webhook auth not configured' }, 503, corsHeaders);
  }

  const authHeader = (request.headers.get('Authorization') || '').trim();
  const providedToken = authHeader.toLowerCase().startsWith('bearer ')
    ? authHeader.slice(7).trim()
    : authHeader;
  if (!constantTimeEqual(providedToken, expectedSecret)) {
    return jsonResponse({ error: 'Unauthorized webhook' }, 401, corsHeaders);
  }

  const payload = safeJsonParse(rawBody);
  const event = payload?.event && typeof payload.event === 'object' ? payload.event : null;
  if (!event) {
    return jsonResponse({ error: 'Invalid RevenueCat event payload' }, 400, corsHeaders);
  }

  const eventId = String(event.id || '').trim();
  const appUserId = String(event.app_user_id || '').trim();
  const eventType = String(event.type || '').trim().toUpperCase();
  const productId = String(event.product_id || '').trim();
  const expirationAtMs = Number(event.expiration_at_ms) || 0;
  const nowMs = Date.now();

  if (!eventId || !appUserId || !eventType) {
    return jsonResponse({ error: 'Missing event.id, app_user_id, or type' }, 400, corsHeaders);
  }

  if (env.RECIPES_DB) {
    try {
      const existing = await env.RECIPES_DB
        .prepare('SELECT event_id FROM revenuecat_events WHERE event_id = ?')
        .bind(eventId)
        .first();
      if (existing) {
        const entitlement = await resolveEntitlement(env, appUserId, nowMs);
        return jsonResponse({ status: 'duplicate_ignored', entitlement }, 200, corsHeaders);
      }

      await env.RECIPES_DB
        .prepare('INSERT INTO revenuecat_events (event_id, app_user_id, event_type, product_id, expiration_at_ms, created_at_ms) VALUES (?, ?, ?, ?, ?, ?)')
        .bind(eventId, appUserId, eventType, productId || null, expirationAtMs || null, nowMs)
        .run();
    } catch {
      // D1 event log write failure must not block entitlement update
    }
  }

  const currentRow = await readEntitlementRecord(env, appUserId);
  const tierLabel = classifySubscriptionTier(productId);
  const isLifetimePurchase = tierLabel === 'lifetime' ||
    (eventType === 'NON_RENEWING_PURCHASE' && !expirationAtMs);

  const grantEvents = new Set([
    'INITIAL_PURCHASE',
    'RENEWAL',
    'UNCANCELLATION',
    'NON_RENEWING_PURCHASE',
    'PRODUCT_CHANGE',
  ]);

  if (grantEvents.has(eventType)) {
    const nextLifetime = (currentRow?.is_lifetime ? 1 : 0) || (isLifetimePurchase ? 1 : 0);
    const nextTier = nextLifetime ? 'lifetime' : tierLabel;
    const nextProUntil = nextLifetime
      ? Math.max(Number(currentRow?.pro_until_ms) || 0, expirationAtMs)
      : Math.max(Number(currentRow?.pro_until_ms) || 0, expirationAtMs || (nowMs + 30 * 24 * HOUR_MS));

    const nextRecord = normalizeEntitlementRecord(appUserId, currentRow);
    nextRecord.tier = nextTier;
    nextRecord.source = 'revenuecat';
    nextRecord.pro_until_ms = nextProUntil;
    nextRecord.is_lifetime = nextLifetime;
    nextRecord.updated_at_ms = nowMs;
    await persistEntitlementRecord(env, nextRecord, { fallbackToKv: true });
  } else if (eventType === 'EXPIRATION') {
    const stillLifetime = Boolean(currentRow?.is_lifetime);
    const hasActiveRewardedPass =
      (currentRow?.source === 'admob_ssv' || currentRow?.source === 'rewarded_ad_client') &&
      (Number(currentRow?.pro_until_ms) || 0) > nowMs;

    if (!stillLifetime && !hasActiveRewardedPass && currentRow) {
      const nextRecord = normalizeEntitlementRecord(appUserId, currentRow);
      nextRecord.tier = 'free';
      nextRecord.source = 'none';
      nextRecord.pro_until_ms = 0;
      nextRecord.updated_at_ms = nowMs;
      await persistEntitlementRecord(env, nextRecord, { fallbackToKv: true });
    }
  }

  const entitlement = await resolveEntitlement(env, appUserId, nowMs);
  return jsonResponse({ status: 'ok', entitlement }, 200, corsHeaders);
}

function base64ToBytes(b64) {
  const normalized = b64.replace(/-/g, '+').replace(/_/g, '/');
  const padded = normalized + '='.repeat((4 - (normalized.length % 4)) % 4);
  const bin = atob(padded);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) {
    bytes[i] = bin.charCodeAt(i);
  }
  return bytes;
}

/**
 * Converts an ASN.1 DER-encoded ECDSA signature (as sent by Google AdMob SSV)
 * into IEEE P1363 raw (r || s) bytes expected by Web Crypto SubtleCrypto.verify.
 */
export function derToP1363(derBytes, componentLen = 32) {
  if (!(derBytes instanceof Uint8Array) || derBytes.length < 8) return null;
  let offset = 0;
  if (derBytes[offset++] !== 0x30) return null;
  let seqLen = derBytes[offset++];
  if (seqLen & 0x80) {
    const lenBytes = seqLen & 0x7f;
    if (lenBytes === 0 || lenBytes > 2 || offset + lenBytes > derBytes.length) return null;
    seqLen = 0;
    for (let i = 0; i < lenBytes; i++) {
      seqLen = (seqLen << 8) | derBytes[offset++];
    }
  }
  if (offset + seqLen !== derBytes.length) return null;

  const readInt = () => {
    if (derBytes[offset++] !== 0x02) return null;
    const len = derBytes[offset++];
    if (len <= 0 || offset + len > derBytes.length) return null;
    let slice = derBytes.subarray(offset, offset + len);
    offset += len;
    while (slice.length > 0 && slice[0] === 0x00) {
      slice = slice.subarray(1);
    }
    if (slice.length > componentLen) return null;
    const padded = new Uint8Array(componentLen);
    padded.set(slice, componentLen - slice.length);
    return padded;
  };

  const r = readInt();
  const s = readInt();
  if (!r || !s || offset !== derBytes.length) return null;

  const out = new Uint8Array(componentLen * 2);
  out.set(r, 0);
  out.set(s, componentLen);
  return out;
}

async function fetchAdMobVerifierKeys(env) {
  if (Array.isArray(env?.ADMOB_VERIFIER_KEYS_OVERRIDE)) {
    return env.ADMOB_VERIFIER_KEYS_OVERRIDE;
  }
  if (env.ORGANIC_SCORE_KV) {
    try {
      const cached = await env.ORGANIC_SCORE_KV.get(ADMOB_KEYS_KV_CACHE_KEY);
      const parsed = cached ? safeJsonParse(cached) : null;
      if (Array.isArray(parsed?.keys) && parsed.keys.length > 0) {
        return parsed.keys;
      }
    } catch {
      // Fallback to live Google AdMob verifier keys fetch
    }
  }
  const resp = await fetch(ADMOB_VERIFIER_KEYS_URL);
  if (!resp.ok) return null;
  const data = await resp.json();
  if (!Array.isArray(data?.keys)) return null;
  if (env.ORGANIC_SCORE_KV) {
    try {
      await env.ORGANIC_SCORE_KV.put(ADMOB_KEYS_KV_CACHE_KEY, JSON.stringify(data), {
        expirationTtl: 86400,
      });
    } catch {
      // Best-effort KV cache write
    }
  }
  return data.keys;
}

function spkiFromVerifierKey(keyObj) {
  if (typeof keyObj.base64 === 'string' && keyObj.base64.trim()) {
    return base64ToBytes(keyObj.base64.trim());
  }
  if (typeof keyObj.pem === 'string' && keyObj.pem.includes('PUBLIC KEY')) {
    const body = keyObj.pem
      .replace(/-----BEGIN PUBLIC KEY-----/g, '')
      .replace(/-----END PUBLIC KEY-----/g, '')
      .replace(/\s+/g, '');
    return base64ToBytes(body);
  }
  return null;
}

async function verifyAdMobSsvSignature(url, env) {
  const rawQuery = url.search.startsWith('?') ? url.search.slice(1) : url.search;
  const sigMarkerIdx = rawQuery.indexOf('&signature=');
  if (sigMarkerIdx <= 0) return { ok: false, reason: 'missing_signature_param' };

  const messageText = rawQuery.slice(0, sigMarkerIdx);
  const signatureB64 = url.searchParams.get('signature') || '';
  const keyId = url.searchParams.get('key_id') || '';
  if (!signatureB64 || !keyId) return { ok: false, reason: 'missing_signature_or_key_id' };

  const keys = await fetchAdMobVerifierKeys(env);
  if (!keys) return { ok: false, reason: 'verifier_keys_unavailable' };

  const matchingKey = keys.find((k) => String(k.keyId) === String(keyId));
  if (!matchingKey) return { ok: false, reason: 'unknown_key_id' };

  const spkiBytes = spkiFromVerifierKey(matchingKey);
  if (!spkiBytes) return { ok: false, reason: 'invalid_verifier_key' };

  let derBytes;
  try {
    derBytes = base64ToBytes(signatureB64);
  } catch (err) {
    return { ok: false, reason: `invalid_signature_encoding:${err.name}` };
  }

  const p1363Sig = derToP1363(derBytes, 32);
  if (!p1363Sig) return { ok: false, reason: 'invalid_der_signature' };

  const cryptoKey = await crypto.subtle.importKey(
    'spki',
    spkiBytes,
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['verify'],
  );

  const valid = await crypto.subtle.verify(
    { name: 'ECDSA', hash: 'SHA-256' },
    cryptoKey,
    p1363Sig,
    new TextEncoder().encode(messageText),
  );
  return valid ? { ok: true } : { ok: false, reason: 'signature_mismatch' };
}

export async function handleAdMobSsvCallback(request, env, corsHeaders) {
  const url = new URL(request.url);
  const txId = (url.searchParams.get('transaction_id') || '').trim();
  const appUserId = (url.searchParams.get('user_id') || url.searchParams.get('custom_data') || '').trim();
  const adUnit = (url.searchParams.get('ad_unit') || '').trim();
  const rewardAmount = Math.max(1, Number(url.searchParams.get('reward_amount')) || 1);

  if (!txId || !appUserId) {
    return jsonResponse({ error: 'Missing transaction_id or user_id' }, 400, corsHeaders);
  }

  const verifyResult = await verifyAdMobSsvSignature(url, env);
  if (!verifyResult.ok) {
    return jsonResponse({ error: 'Invalid AdMob SSV signature', reason: verifyResult.reason }, 403, corsHeaders);
  }

  const nowMs = Date.now();
  if (env.RECIPES_DB) {
    try {
      const existingTx = await env.RECIPES_DB
        .prepare('SELECT transaction_id FROM admob_ssv_events WHERE transaction_id = ?')
        .bind(txId)
        .first();
      if (existingTx) {
        const entitlement = await resolveEntitlement(env, appUserId, nowMs);
        return jsonResponse({ status: 'duplicate_ignored', entitlement }, 200, corsHeaders);
      }

      await env.RECIPES_DB
        .prepare('INSERT INTO admob_ssv_events (transaction_id, app_user_id, ad_unit, reward_amount, created_at_ms) VALUES (?, ?, ?, ?, ?)')
        .bind(txId, appUserId, adUnit || null, rewardAmount, nowMs)
        .run();
    } catch {
      // D1 write quota errors must not block SSV reward grant
    }
  }

  const grantResult = await grantRewardedAdStepInDb(env, appUserId, 'admob_ssv', nowMs);
  return jsonResponse({
    status: grantResult.status,
    unlocked_pro_3h: grantResult.unlockedPro,
    entitlement: grantResult.entitlement,
  }, 200, corsHeaders);
}

async function grantRewardedAdStepInDb(env, appUserId, grantSource, nowMs = Date.now()) {
  const today = utcDateString(nowMs);
  const adsRequired = envNumber(env, 'REWARD_ADS_REQUIRED', 3);
  const rewardHours = envNumber(env, 'REWARD_PRO_HOURS', 3);
  const maxDailyPasses = envNumber(env, 'REWARD_DAILY_MAX_PASSES', 2);

  const row = await readEntitlementRecord(env, appUserId);
  const passesToday = (row && row.reward_passes_date === today)
    ? (Number(row.reward_passes_today) || 0)
    : 0;
  if (passesToday >= maxDailyPasses) {
    const entitlement = await resolveEntitlement(env, appUserId, nowMs);
    return { status: 'daily_limit_reached', unlockedPro: false, entitlement };
  }

  const lastGrantMs = Number(row?.last_ad_reward_ms) || 0;
  const resetMs = Number(row?.ad_window_reset_ms) || 0;
  const currentProgress = (!row || (resetMs > 0 && resetMs <= nowMs))
    ? 0
    : (Number(row.ad_progress_count) || 0);
  const nextProgress = currentProgress + 1;
  const unlockedPro = nextProgress >= adsRequired;

  const currentProUntil = Number(row?.pro_until_ms) || 0;
  const nextProUntil = unlockedPro
    ? Math.max(nowMs, currentProUntil) + rewardHours * HOUR_MS
    : currentProUntil;
  const storedProgress = unlockedPro ? 0 : nextProgress;
  const nextWindowReset = unlockedPro ? 0 : (nowMs + 24 * HOUR_MS);
  const nextLastReward = unlockedPro ? nowMs : lastGrantMs;
  const nextPassesToday = unlockedPro ? passesToday + 1 : passesToday;

  const nextRecord = normalizeEntitlementRecord(appUserId, row);
  if (unlockedPro && !row?.is_lifetime) {
    nextRecord.tier = 'rewarded_pro';
    nextRecord.source = grantSource;
  }
  nextRecord.pro_until_ms = nextProUntil;
  nextRecord.ad_progress_count = storedProgress;
  nextRecord.ad_window_reset_ms = nextWindowReset;
  nextRecord.last_ad_reward_ms = nextLastReward;
  nextRecord.reward_passes_date = today;
  nextRecord.reward_passes_today = nextPassesToday;
  nextRecord.updated_at_ms = nowMs;

  await persistEntitlementRecord(env, nextRecord, { fallbackToKv: true });

  const entitlement = await resolveEntitlement(env, appUserId, nowMs);
  return { status: 'ok', unlockedPro, entitlement };
}

export async function handleRewardedAdStep(request, env, corsHeaders) {
  const appUserId = extractAppUserId(request);
  if (!appUserId) {
    return jsonResponse({ error: 'Missing or invalid X-Kilerce-User-Id header' }, 400, corsHeaders);
  }
  const grantResult = await grantRewardedAdStepInDb(
    env,
    appUserId,
    'rewarded_ad_client',
    Date.now(),
  );
  return jsonResponse({
    status: grantResult.status,
    unlocked_pro_3h: grantResult.unlockedPro,
    entitlement: grantResult.entitlement,
  }, 200, corsHeaders);
}

export async function handleRedeemPromoCode(request, env, corsHeaders, rawBody) {
  const appUserId = extractAppUserId(request);
  if (!appUserId) {
    return jsonResponse({ error: 'Missing or invalid X-Kilerce-User-Id header' }, 400, corsHeaders);
  }

  const payload = safeJsonParse(rawBody);
  const code = typeof payload?.code === 'string' ? payload.code.trim().toUpperCase() : '';
  let durationMs = 0;
  let promoTier = 'free';

  if (TESTER_PROMO_CODES.has(code)) {
    durationMs = 365 * 24 * HOUR_MS;
    promoTier = 'tester';
  } else if (CAMPAIGN_PROMO_CODES.has(code)) {
    durationMs = 72 * HOUR_MS;
    promoTier = 'campaign_pro';
  } else {
    return jsonResponse({
      error: 'INVALID_PROMO_CODE',
      message: 'Geçersiz veya süresi dolmuş promosyon kodu.',
    }, 400, corsHeaders);
  }

  const nowMs = Date.now();
  const currentRow = await readEntitlementRecord(env, appUserId);
  const isLifetime = Boolean(currentRow?.is_lifetime);
  const nextRecord = normalizeEntitlementRecord(appUserId, currentRow);
  nextRecord.tier = isLifetime ? 'lifetime' : promoTier;
  nextRecord.source = isLifetime ? (currentRow?.source || 'revenuecat') : 'promo_code';
  nextRecord.pro_until_ms = Math.max(
    Number(currentRow?.pro_until_ms) || 0,
    nowMs + durationMs,
  );
  nextRecord.is_lifetime = isLifetime ? 1 : 0;
  nextRecord.updated_at_ms = nowMs;

  await persistEntitlementRecord(env, nextRecord, { fallbackToKv: true });

  const entitlement = await resolveEntitlement(env, appUserId, nowMs);
  return jsonResponse({ status: 'ok', entitlement }, 200, corsHeaders);
}
