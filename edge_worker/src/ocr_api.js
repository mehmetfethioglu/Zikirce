import { extractAppUserId, utcDateString } from './entitlements.js';
import { jsonResponse, safeJsonParse } from './security.js';

const MAX_IMAGE_BASE64_LEN = 2_100_000;
const ALLOWED_MIME_TYPES = new Set(['image/jpeg', 'image/webp', 'image/png']);
const ALLOWED_STORAGE_ZONES = new Set(['FRIDGE', 'PANTRY', 'FREEZER']);

const RECEIPT_SYSTEM_PROMPT = `Sen bir Türk market fişi ayrıştırıcısısın. Fotoğraftan SADECE gıda/mutfak ürünlerini çıkar ve kısaltmaları anlaşılır Türkçeye aç (ör. "YRM YAG SUT 1L" -> "Yarım Yağlı Süt", "SLK DOMATES" -> "Salkım Domates").
KDV, ara toplam, toplam, kredi kartı, fiş no, mağaza başlığı, poşet, temizlik ve gıda dışı kalemleri KESİNLİKLE hariç tut.
Sadece geçerli JSON döndür:
{
  "items": [
    {
      "name": "Temiz ürün adı (Türkçe karakterli)",
      "raw_line": "Fişteki orijinal satır",
      "unit_label": "1 Lt veya 500 gr veya 1 Adet",
      "storage_zone": "FRIDGE | PANTRY | FREEZER"
    }
  ]
}`;

const PRODUCT_LABEL_SYSTEM_PROMPT = `Sen bir Türk gıda etiketi uzmanısın. Fotoğraftaki ürün ambalajından veya içindekiler etiketinden okunabilen alanları Türkçe karakterleri (ç, ğ, ı, İ, ö, ş, ü) koruyarak çıkar.
Okunamayan alanları boş string veya boş dizi bırak; uydurma yapma. Sadece geçerli JSON döndür:
{
  "brand": "Marka adı",
  "product_name": "Ürün tam adı",
  "net_quantity": "Net miktar (ör. 500 g, 1 L)",
  "ingredients_text": "İçindekiler metni (tam ve virgüllü)",
  "allergens": ["Alerjen 1"]
}`;

async function sha256Hex(text) {
  const bytes = new TextEncoder().encode(text);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

function normalizeImageInput(body) {
  let rawB64 = typeof body?.image_base64 === 'string' ? body.image_base64.trim() : '';
  let mimeType = typeof body?.mime_type === 'string' ? body.mime_type.trim().toLowerCase() : '';

  const dataUriMatch = rawB64.match(/^data:(image\/[a-z0-9.+-]+);base64,(.+)$/i);
  if (dataUriMatch) {
    if (!mimeType) mimeType = dataUriMatch[1].toLowerCase();
    rawB64 = dataUriMatch[2].trim();
  }

  if (!ALLOWED_MIME_TYPES.has(mimeType)) {
    mimeType = 'image/jpeg';
  }

  if (!rawB64 || rawB64.length > MAX_IMAGE_BASE64_LEN) {
    return null;
  }

  return { imageBase64: rawB64, mimeType };
}

function sanitizeText(val, maxLen) {
  if (typeof val !== 'string') return '';
  return val.replace(/\s+/g, ' ').trim().slice(0, maxLen);
}

async function runGeminiVisionOcr({ request, env, corsHeaders, mode, imageBase64, mimeType, promptText }) {
  const apiKey = typeof env.GEMINI_API_KEY === 'string' ? env.GEMINI_API_KEY.trim() : '';
  if (!apiKey) {
    return {
      errorResponse: jsonResponse(
        { error: 'GEMINI_NOT_CONFIGURED', message: 'Bulut OCR anahtarı tanımlı değil.' },
        503,
        corsHeaders,
      ),
    };
  }

  const cacheHash = await sha256Hex(`${mode}:${imageBase64}`);
  const cacheKey = `ocr_cache:${mode}:${cacheHash}`;

  if (env.ORGANIC_SCORE_KV) {
    try {
      const cachedRaw = await env.ORGANIC_SCORE_KV.get(cacheKey);
      const cachedParsed = cachedRaw ? safeJsonParse(cachedRaw) : null;
      if (cachedParsed && typeof cachedParsed === 'object') {
        return {
          payload: {
            ...cachedParsed,
            cached: true,
          },
        };
      }
    } catch {
      // Cache read failure must not block OCR
    }
  }

  const ocrLimit = Math.max(1, Number(env.OCR_DAILY_LIMIT) || 15);
  const actor = extractAppUserId(request) || request.headers.get('CF-Connecting-IP') || 'unknown';
  const quotaKey = `ocr_daily:${actor}:${utcDateString(Date.now())}`;

  if (env.ORGANIC_SCORE_KV) {
    try {
      const usedRaw = await env.ORGANIC_SCORE_KV.get(quotaKey);
      const used = usedRaw ? Number(usedRaw) || 0 : 0;
      if (used >= ocrLimit) {
        return {
          errorResponse: jsonResponse(
            {
              error: 'OCR_DAILY_LIMIT_EXCEEDED',
              message: 'Günlük bulut OCR kullanım sınırına ulaşıldı.',
            },
            429,
            corsHeaders,
          ),
        };
      }
      await env.ORGANIC_SCORE_KV.put(quotaKey, String(used + 1), { expirationTtl: 86400 });
    } catch {
      // KV quota errors must not block OCR
    }
  }

  const model = (typeof env.GEMINI_OCR_MODEL === 'string' && env.GEMINI_OCR_MODEL.trim())
    ? env.GEMINI_OCR_MODEL.trim()
    : 'gemini-3.5-flash-lite';

  const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`;
  const geminiResp = await fetch(geminiUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-goog-api-key': apiKey,
    },
    body: JSON.stringify({
      contents: [
        {
          parts: [
            { text: promptText },
            {
              inline_data: {
                mime_type: mimeType,
                data: imageBase64,
              },
            },
          ],
        },
      ],
      generationConfig: {
        response_mime_type: 'application/json',
        temperature: 0.1,
        maxOutputTokens: 1024,
        thinkingConfig: { thinkingLevel: 'minimal' },
      },
    }),
  });

  if (!geminiResp.ok) {
    let errBody = null;
    try {
      errBody = safeJsonParse(await geminiResp.text());
    } catch {
      errBody = null;
    }
    const upstreamMsg = String(errBody?.error?.message || '').slice(0, 180);
    return {
      errorResponse: jsonResponse(
        {
          error: 'Upstream OCR AI service unavailable',
          upstream_status: geminiResp.status,
          ...(upstreamMsg ? { upstream_message: upstreamMsg } : {}),
        },
        502,
        corsHeaders,
      ),
    };
  }

  const geminiData = await geminiResp.json();
  const rawText = geminiData?.candidates?.[0]?.content?.parts?.[0]?.text;
  const parsed = typeof rawText === 'string' ? safeJsonParse(rawText) : null;
  if (!parsed || typeof parsed !== 'object') {
    return {
      errorResponse: jsonResponse({ error: 'Invalid upstream OCR AI response' }, 502, corsHeaders),
    };
  }

  return { parsed, cacheKey, model };
}

export async function handleOcrReceipt(request, env, corsHeaders, rawBody) {
  const body = safeJsonParse(rawBody);
  const img = normalizeImageInput(body);
  if (!img) {
    return jsonResponse({ error: 'Invalid or oversized image_base64' }, 400, corsHeaders);
  }

  const res = await runGeminiVisionOcr({
    request,
    env,
    corsHeaders,
    mode: 'receipt',
    imageBase64: img.imageBase64,
    mimeType: img.mimeType,
    promptText: RECEIPT_SYSTEM_PROMPT,
  });

  if (res.errorResponse) return res.errorResponse;
  if (res.payload) return jsonResponse(res.payload, 200, corsHeaders);

  const rawItems = Array.isArray(res.parsed.items) ? res.parsed.items : [];
  const items = [];
  for (const raw of rawItems.slice(0, 40)) {
    if (!raw || typeof raw !== 'object') continue;
    const name = sanitizeText(raw.name, 80);
    if (name.length < 2) continue;
    const rawLine = sanitizeText(raw.raw_line, 100) || name;
    const unitLabel = sanitizeText(raw.unit_label, 30) || '1 Paket';
    const zoneCandidate = sanitizeText(raw.storage_zone, 16).toUpperCase();
    const storageZone = ALLOWED_STORAGE_ZONES.has(zoneCandidate) ? zoneCandidate : 'PANTRY';

    items.push({
      name,
      raw_line: rawLine,
      unit_label: unitLabel,
      storage_zone: storageZone,
    });
  }

  const payload = {
    source: 'gemini_flash_lite',
    model: res.model,
    cached: false,
    items,
  };

  if (env.ORGANIC_SCORE_KV && res.cacheKey) {
    try {
      await env.ORGANIC_SCORE_KV.put(res.cacheKey, JSON.stringify(payload), { expirationTtl: 86400 });
    } catch {
      // Best-effort KV cache write
    }
  }

  return jsonResponse(payload, 200, corsHeaders);
}

export async function handleOcrProductLabel(request, env, corsHeaders, rawBody) {
  const body = safeJsonParse(rawBody);
  const img = normalizeImageInput(body);
  if (!img) {
    return jsonResponse({ error: 'Invalid or oversized image_base64' }, 400, corsHeaders);
  }

  const modeRaw = sanitizeText(body?.mode, 24).toUpperCase();
  const modeHint = modeRaw === 'PACKAGING'
    ? '\nOdak: Ön yüz ambalajdan özellikle brand, product_name ve net_quantity bilgilerini çıkar.'
    : (modeRaw === 'INGREDIENTS'
      ? '\nOdak: Arka yüz etiketten özellikle ingredients_text ve allergens bilgilerini tam ve eksiksiz çıkar.'
      : '');

  const res = await runGeminiVisionOcr({
    request,
    env,
    corsHeaders,
    mode: `label_${modeRaw || 'AUTO'}`,
    imageBase64: img.imageBase64,
    mimeType: img.mimeType,
    promptText: `${PRODUCT_LABEL_SYSTEM_PROMPT}${modeHint}`,
  });

  if (res.errorResponse) return res.errorResponse;
  if (res.payload) return jsonResponse(res.payload, 200, corsHeaders);

  const allergens = Array.isArray(res.parsed.allergens)
    ? res.parsed.allergens
        .map((a) => sanitizeText(a, 50))
        .filter((a) => a.length > 0)
        .slice(0, 16)
    : [];

  const payload = {
    source: 'gemini_flash_lite',
    model: res.model,
    cached: false,
    brand: sanitizeText(res.parsed.brand, 80),
    product_name: sanitizeText(res.parsed.product_name, 140),
    net_quantity: sanitizeText(res.parsed.net_quantity, 32),
    ingredients_text: sanitizeText(res.parsed.ingredients_text, 2200),
    allergens,
  };

  if (env.ORGANIC_SCORE_KV && res.cacheKey) {
    try {
      await env.ORGANIC_SCORE_KV.put(res.cacheKey, JSON.stringify(payload), { expirationTtl: 86400 });
    } catch {
      // Best-effort KV cache write
    }
  }

  return jsonResponse(payload, 200, corsHeaders);
}
