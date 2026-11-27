const RATE_WINDOW_SECONDS = 60;
const MAX_POST_PER_MIN = 30;
const MAX_GET_PER_MIN = 120;
const MAX_TIMESTAMP_SKEW_SECONDS = 300;
const MAX_RATE_LIMIT_BUCKETS = 2000;

const _inMemoryRateBuckets = new Map();

export function resetRateLimitForTesting() {
  _inMemoryRateBuckets.clear();
}

const TURKISH_CHAR_MAP = {
  'ç': 'c',
  'Ç': 'c',
  'ğ': 'g',
  'Ğ': 'g',
  'ı': 'i',
  'I': 'i',
  'İ': 'i',
  'ö': 'o',
  'Ö': 'o',
  'ş': 's',
  'Ş': 's',
  'ü': 'u',
  'Ü': 'u',
  'â': 'a',
  'Â': 'a',
  'î': 'i',
  'Î': 'i',
  'û': 'u',
  'Û': 'u',
};

export function jsonResponse(data, status, corsHeaders, extraHeaders = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json; charset=utf-8',
      ...extraHeaders,
    },
  });
}

export function safeJsonParse(raw) {
  if (typeof raw !== 'string' || !raw.trim()) return null;
  try {
    return JSON.parse(raw);
  } catch (err) {
    if (err instanceof SyntaxError) return null;
    return null;
  }
}

export function constantTimeEqual(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string') return false;
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

export function simpleHash(str) {
  let hash = 0;
  if (!str || str.length === 0) return hash.toString();
  for (let i = 0; i < str.length; i++) {
    const char = str.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash |= 0;
  }
  return Math.abs(hash).toString();
}

export function turkishFold(input) {
  if (typeof input !== 'string' || !input) return '';
  let out = '';
  for (let i = 0; i < input.length; i++) {
    const ch = input[i];
    out += TURKISH_CHAR_MAP[ch] ?? ch.toLowerCase();
  }
  return out
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

export function isValidGs1Barcode(code) {
  return /^\d{8}$/.test(code) || /^\d{13}$/.test(code);
}

export function clampScore(val, fallback) {
  const n = Number(val);
  if (!Number.isFinite(n)) return fallback;
  return Math.max(0, Math.min(100, Math.round(n)));
}

export function clampNova(val, fallback) {
  const n = Number(val);
  if (!Number.isFinite(n)) return fallback;
  return Math.max(1, Math.min(4, Math.round(n)));
}

export async function hmacSha256Hex(secret, message) {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sigBuffer = await crypto.subtle.sign('HMAC', key, encoder.encode(message));
  return Array.from(new Uint8Array(sigBuffer))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

/**
 * Verifies request HMAC-SHA256 signature when env.HMAC_SECRET is configured.
 * Supports canonical `${ts}.${method}.${pathAndQuery}.${rawBody}` for all methods
 * plus legacy `${ts}.${rawBody}` for backward-compatible POST clients.
 */
export async function verifyHmacSignature(request, rawBody, env) {
  if (!env.HMAC_SECRET) return true;
  const sigHex = (request.headers.get('X-OrganicScore-Signature') || '').trim().toLowerCase();
  const tsHeader = request.headers.get('X-OrganicScore-Timestamp') || '';
  const ts = Number(tsHeader);
  if (!sigHex || !Number.isFinite(ts)) return false;

  const nowSec = Math.floor(Date.now() / 1000);
  if (Math.abs(nowSec - ts) > MAX_TIMESTAMP_SKEW_SECONDS) return false;

  const url = new URL(request.url);
  const pathAndQuery = `${url.pathname}${url.search}`;
  const canonicalPayload = `${ts}.${request.method.toUpperCase()}.${pathAndQuery}.${rawBody || ''}`;
  const expectedCanonical = await hmacSha256Hex(env.HMAC_SECRET, canonicalPayload);
  if (constantTimeEqual(sigHex, expectedCanonical)) return true;

  if (request.method === 'POST') {
    const legacyPayload = `${ts}.${rawBody || ''}`;
    const expectedLegacy = await hmacSha256Hex(env.HMAC_SECRET, legacyPayload);
    return constantTimeEqual(sigHex, expectedLegacy);
  }
  return false;
}

export async function checkRateLimit(request, _env) {
  const ip = request.headers.get('CF-Connecting-IP') || 'unknown';
  const bucket = Math.floor(Date.now() / (RATE_WINDOW_SECONDS * 1000));
  const method = request.method === 'POST' ? 'POST' : 'GET';
  const limit = method === 'POST' ? MAX_POST_PER_MIN : MAX_GET_PER_MIN;
  const key = `rl:${method}:${ip}:${bucket}`;

  if (_inMemoryRateBuckets.size > MAX_RATE_LIMIT_BUCKETS) {
    for (const [entryKey, entry] of _inMemoryRateBuckets.entries()) {
      if (entry.bucket < bucket) {
        _inMemoryRateBuckets.delete(entryKey);
      }
    }
    if (_inMemoryRateBuckets.size > MAX_RATE_LIMIT_BUCKETS) {
      _inMemoryRateBuckets.clear();
    }
  }

  const current = _inMemoryRateBuckets.get(key)?.count || 0;
  if (current >= limit) return false;
  _inMemoryRateBuckets.set(key, { bucket, count: current + 1 });
  return true;
}

export async function signMediaToken(relPath, expSec, secret) {
  if (!secret) return 'unsigned';
  const payload = `${relPath}:${expSec}`;
  return hmacSha256Hex(secret, payload);
}

export async function verifyMediaToken(relPath, expSec, sigHex, secret, nowSec = Math.floor(Date.now() / 1000)) {
  if (!secret) return true;
  if (!Number.isFinite(expSec) || expSec < nowSec) return false;
  if (typeof sigHex !== 'string' || !sigHex) return false;
  const expected = await signMediaToken(relPath, expSec, secret);
  return constantTimeEqual(sigHex.toLowerCase(), expected);
}

export async function buildSignedMediaUrl(request, env, relPath, nowMs = Date.now()) {
  if (!relPath) return null;
  const ttlSec = Math.max(60, Number(env.SIGNED_MEDIA_TTL_SEC) || 900);
  const expSec = Math.floor(nowMs / 1000) + ttlSec;
  const mediaSecret = env.MEDIA_SIGNING_SECRET || env.HMAC_SECRET || '';
  const sig = await signMediaToken(relPath, expSec, mediaSecret);
  const origin = new URL(request.url).origin;
  const encodedPath = relPath
    .split('/')
    .map((part) => encodeURIComponent(part))
    .join('/');
  return `${origin}/api/media/${encodedPath}?exp=${expSec}&sig=${sig}`;
}
