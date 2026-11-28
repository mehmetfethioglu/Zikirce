import {
  consumeFreeDetailQuota,
  consumeIpFreeDetailQuota,
  extractAppUserId,
  resolveEntitlement,
} from './entitlements.js';
import {
  buildSignedMediaUrl,
  jsonResponse,
  safeJsonParse,
  turkishFold,
  verifyMediaToken,
} from './security.js';

const MAX_LIST_LIMIT = 20;
const MAX_SEARCH_PAGE = 50;
const MAX_PANTRY_TAGS = 60;
const MAX_PANTRY_OFFSET = 200;
const MAX_SQL_MATCH_TAGS = 12;
const MAX_SQL_STAPLE_FALLBACK_TAGS = 8;

const MEM_CACHE_TTL_MS = 15 * 60 * 1000;
const MEM_DETAIL_CACHE_TTL_MS = 30 * 60 * 1000;
const MAX_MEM_PANTRY_ENTRIES = 200;
const MAX_MEM_SEARCH_ENTRIES = 200;
const MAX_MEM_DETAIL_ENTRIES = 300;
const MAX_MEM_PREVIEW_ROWS = 2500;
const MEM_PREVIEW_ROW_TTL_MS = 60 * 60 * 1000;
const KV_CACHE_TTL_SEC = 86400;
const PANTRY_INDEX_R2_KEY = 'pantry_idx/v1/compact_index.json';
const MAX_PANTRY_CANDIDATES = 220;

const HIGH_FREQ_STAPLE_TAGS = new Set([
  'sumak_isot',
  'un',
  'tereyagi',
  'zeytinyagi',
  'aycicek_yagi',
  'tuz',
  'seker',
  'karabiber',
  'su',
  'sivi_yag',
  'kabartma_tozu',
  'vanilya',
]);

const _memPantryCache = new Map();
const _memSearchCache = new Map();
const _memDetailCache = new Map();
const _memPreviewRowCache = new Map();
let _compactPantryIndex = null;
let _compactPantryIndexPromise = null;

export function resetRecipeCachesForTesting() {
  _memPantryCache.clear();
  _memSearchCache.clear();
  _memDetailCache.clear();
  _memPreviewRowCache.clear();
  _compactPantryIndex = null;
  _compactPantryIndexPromise = null;
}

function getMemCache(map, key, nowMs = Date.now()) {
  const entry = map.get(key);
  if (!entry) return null;
  if (entry.expiresAt <= nowMs) {
    map.delete(key);
    return null;
  }
  return entry.value;
}

function setMemCache(map, key, value, ttlMs, maxSize, nowMs = Date.now()) {
  if (map.has(key)) {
    map.delete(key);
  } else if (map.size >= maxSize) {
    for (const [k, v] of map.entries()) {
      if (v.expiresAt <= nowMs) {
        map.delete(k);
      }
    }
    while (map.size >= maxSize) {
      const oldestKey = map.keys().next().value;
      if (oldestKey === undefined) break;
      map.delete(oldestKey);
    }
  }
  map.set(key, { value, expiresAt: nowMs + ttlMs });
}

async function sha256HexShort(text) {
  const bytes = new TextEncoder().encode(text);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('')
    .slice(0, 32);
}

async function readKvJsonCache(env, key) {
  if (!env?.ORGANIC_SCORE_KV) return null;
  try {
    const raw = await env.ORGANIC_SCORE_KV.get(key);
    if (typeof raw !== 'string' || !raw) return null;
    return safeJsonParse(raw);
  } catch {
    return null;
  }
}

async function writeKvJsonCache(env, key, payload, ttlSec, ctx) {
  if (!env?.ORGANIC_SCORE_KV) return;
  try {
    const putPromise = env.ORGANIC_SCORE_KV.put(key, JSON.stringify(payload), {
      expirationTtl: ttlSec,
    });
    if (ctx && typeof ctx.waitUntil === 'function') {
      ctx.waitUntil(putPromise.catch(() => {}));
    } else {
      await putPromise;
    }
  } catch {
    // Best-effort KV cache write; daily KV limits must never cause HTTP 500
  }
}

async function loadCompactPantryIndex(env) {
  if (_compactPantryIndex) return _compactPantryIndex;
  if (!env?.RECIPE_MEDIA) return null;
  if (_compactPantryIndexPromise) return _compactPantryIndexPromise;

  _compactPantryIndexPromise = (async () => {
    try {
      const obj = await env.RECIPE_MEDIA.get(PANTRY_INDEX_R2_KEY);
      if (!obj) return null;
      const raw = typeof obj.json === 'function'
        ? await obj.json()
        : await new Response(obj.body).json();
      if (
        !raw ||
        !Array.isArray(raw.cats) ||
        !Array.isArray(raw.tags) ||
        !Array.isArray(raw.recipes)
      ) {
        return null;
      }
      const catIndexByName = new Map(raw.cats.map((c, i) => [c, i]));
      const tagIndexByName = new Map(raw.tags.map((t, i) => [t, i]));
      _compactPantryIndex = {
        cats: raw.cats,
        tags: raw.tags,
        catIndexByName,
        tagIndexByName,
        recipes: raw.recipes,
      };
      return _compactPantryIndex;
    } catch {
      return null;
    } finally {
      _compactPantryIndexPromise = null;
    }
  })();

  return _compactPantryIndexPromise;
}

async function fetchPreviewRowsByIds(env, ids, nowMs = Date.now()) {
  const rowsById = new Map();
  const missingIds = [];

  for (const id of ids) {
    const cached = getMemCache(_memPreviewRowCache, id, nowMs);
    if (cached) {
      rowsById.set(id, cached);
    } else {
      missingIds.push(id);
    }
  }

  if (missingIds.length > 0 && env?.RECIPES_DB) {
    const placeholders = missingIds.map(() => '?').join(', ');
    const sql = `
      SELECT ${PREVIEW_COLUMNS}
      FROM recipes r
      WHERE r.id IN (${placeholders})
    `;
    const result = await env.RECIPES_DB.prepare(sql).bind(...missingIds).all();
    for (const row of result?.results || []) {
      if (row?.id) {
        rowsById.set(row.id, row);
        setMemCache(
          _memPreviewRowCache,
          row.id,
          row,
          MEM_PREVIEW_ROW_TTL_MS,
          MAX_MEM_PREVIEW_ROWS,
          nowMs,
        );
      }
    }
  }

  return { rowsById, d1FetchedCount: missingIds.length };
}

function selectQueryTags(pantryTags, expiringSet) {
  const nonStaple = [];
  const staple = [];
  for (const tag of pantryTags) {
    if (HIGH_FREQ_STAPLE_TAGS.has(tag)) {
      staple.push(tag);
    } else {
      nonStaple.push(tag);
    }
  }

  let selected;
  if (nonStaple.length >= 2) {
    const expiringNonStaple = nonStaple.filter((t) => expiringSet.has(t));
    const regularNonStaple = nonStaple.filter((t) => !expiringSet.has(t));
    selected = [...expiringNonStaple, ...regularNonStaple].slice(0, MAX_SQL_MATCH_TAGS);
  } else {
    const expiringNonStaple = nonStaple.filter((t) => expiringSet.has(t));
    const expiringStaple = staple.filter((t) => expiringSet.has(t));
    const regularNonStaple = nonStaple.filter((t) => !expiringSet.has(t));
    const regularStaple = staple.filter((t) => !expiringSet.has(t));
    selected = [
      ...expiringNonStaple,
      ...expiringStaple,
      ...regularNonStaple,
      ...regularStaple,
    ].slice(0, MAX_SQL_STAPLE_FALLBACK_TAGS);
  }

  return [...selected].sort();
}

const PREVIEW_COLUMNS = `
  r.id, r.title, r.subtitle, r.emoji, r.category, r.kilerce_category, r.region_id,
  r.prep_minutes, r.cook_minutes, r.total_minutes, r.servings_count, r.servings_label,
  r.difficulty, r.cooking_method, r.contains_gluten, r.contains_lactose,
  r.is_vegan, r.is_vegetarian, r.is_refined_sugar_free, r.is_healthy_clean,
  r.base_health_score, r.quality_score, r.clean_label_badges_json,
  r.meal_slots_json, r.required_tags_json, r.image_rel_path
`;

function parseJsonArray(raw) {
  const parsed = safeJsonParse(raw);
  return Array.isArray(parsed) ? parsed : [];
}

function truthyFlag(val) {
  return val === '1' || val === 'true';
}

async function formatPreviewCard(request, env, row, extra = {}) {
  const imageUrl = await buildSignedMediaUrl(request, env, row.image_rel_path);
  return {
    id: row.id,
    title: row.title,
    subtitle: row.subtitle,
    emoji: row.emoji,
    category: row.category,
    kilerce_category: row.kilerce_category,
    region_id: row.region_id,
    prep_minutes: Number(row.prep_minutes) || 0,
    cook_minutes: Number(row.cook_minutes) || 0,
    total_minutes: Number(row.total_minutes) || 0,
    servings_count: Number(row.servings_count) || 2,
    servings_label: row.servings_label,
    difficulty: row.difficulty,
    cooking_method: row.cooking_method,
    contains_gluten: Boolean(row.contains_gluten),
    contains_lactose: Boolean(row.contains_lactose),
    is_vegan: Boolean(row.is_vegan),
    is_vegetarian: Boolean(row.is_vegetarian),
    is_refined_sugar_free: Boolean(row.is_refined_sugar_free),
    is_healthy_clean: Boolean(row.is_healthy_clean),
    base_health_score: Number(row.base_health_score) || 0,
    quality_score: Number(row.quality_score) || 0,
    clean_label_badges: parseJsonArray(row.clean_label_badges_json),
    meal_slots: parseJsonArray(row.meal_slots_json),
    required_tags: parseJsonArray(row.required_tags_json),
    image_rel_path: row.image_rel_path,
    image_url: imageUrl,
    ...extra,
  };
}

export async function handleRecipesSearch(request, env, corsHeaders, ctx) {
  if (!env.RECIPES_DB) {
    return jsonResponse({ error: 'RECIPES_DB binding not configured' }, 503, corsHeaders);
  }

  const url = new URL(request.url);
  const limit = Math.max(1, Math.min(MAX_LIST_LIMIT, Number(url.searchParams.get('limit')) || 20));
  const page = Math.max(1, Math.min(MAX_SEARCH_PAGE, Number(url.searchParams.get('page')) || 1));
  const offset = (page - 1) * limit;

  const qRaw = (url.searchParams.get('q') || '').trim().slice(0, 100);
  const foldedQ = turkishFold(qRaw);
  const ftsTokens = foldedQ ? foldedQ.split(/\s+/).filter(Boolean).slice(0, 6) : [];

  const kilerceCat = (url.searchParams.get('kilerce_category') || '').trim();
  const category = (url.searchParams.get('category') || '').trim();
  const regionId = (url.searchParams.get('region_id') || '').trim();
  const normalizedRegionId = regionId && regionId !== 'all' ? regionId : '';
  const healthyOnly = truthyFlag(url.searchParams.get('healthy_only'));
  const veganOnly = truthyFlag(url.searchParams.get('vegan'));
  const glutenFree = truthyFlag(url.searchParams.get('gluten_free'));
  const maxMinutesRaw = Number(url.searchParams.get('max_minutes')) || 0;
  const maxMinutes = maxMinutesRaw > 0 ? maxMinutesRaw : 0;

  const cacheKey = JSON.stringify({
    q: ftsTokens.join(' '),
    kilerceCat,
    category,
    regionId: normalizedRegionId,
    healthyOnly,
    veganOnly,
    glutenFree,
    maxMinutes,
    page,
    limit,
  });

  const nowMs = Date.now();
  let cacheStatus = 'MISS';
  let rawRows = getMemCache(_memSearchCache, cacheKey, nowMs);
  let kvCacheKey = null;

  if (rawRows) {
    cacheStatus = 'HIT-MEM';
  } else {
    kvCacheKey = `srch_v1:${await sha256HexShort(cacheKey)}`;
    const kvCached = await readKvJsonCache(env, kvCacheKey);
    if (Array.isArray(kvCached)) {
      rawRows = kvCached;
      cacheStatus = 'HIT-KV';
      setMemCache(_memSearchCache, cacheKey, rawRows, MEM_CACHE_TTL_MS, MAX_MEM_SEARCH_ENTRIES, nowMs);
    }
  }

  if (!rawRows) {
    const whereClauses = [];
    const bindings = [];

    let fromSql = 'FROM recipes r';
    if (ftsTokens.length > 0) {
      const ftsQuery = ftsTokens.map((t) => `${t}*`).join(' ');
      fromSql = 'FROM recipes r INNER JOIN recipes_fts f ON f.recipe_id = r.id';
      whereClauses.push('recipes_fts MATCH ?');
      bindings.push(ftsQuery);
    }

    if (kilerceCat) {
      whereClauses.push('r.kilerce_category = ?');
      bindings.push(kilerceCat);
    }
    if (category) {
      whereClauses.push('r.category = ?');
      bindings.push(category);
    }
    if (normalizedRegionId) {
      whereClauses.push('r.region_id = ?');
      bindings.push(normalizedRegionId);
    }
    if (healthyOnly) {
      whereClauses.push('r.is_healthy_clean = 1');
    }
    if (veganOnly) {
      whereClauses.push('r.is_vegan = 1');
    }
    if (glutenFree) {
      whereClauses.push('r.contains_gluten = 0');
    }
    if (maxMinutes > 0) {
      whereClauses.push('r.total_minutes <= ?');
      bindings.push(maxMinutes);
    }

    const whereSql = whereClauses.length > 0 ? `WHERE ${whereClauses.join(' AND ')}` : '';
    const dataSql = `
      SELECT ${PREVIEW_COLUMNS}
      ${fromSql}
      ${whereSql}
      ORDER BY r.quality_score DESC, r.base_health_score DESC
      LIMIT ? OFFSET ?
    `;

    const result = await env.RECIPES_DB
      .prepare(dataSql)
      .bind(...bindings, limit + 1, offset)
      .all();

    rawRows = result?.results || [];
    setMemCache(_memSearchCache, cacheKey, rawRows, MEM_CACHE_TTL_MS, MAX_MEM_SEARCH_ENTRIES, nowMs);
    if (kvCacheKey) {
      await writeKvJsonCache(env, kvCacheKey, rawRows, KV_CACHE_TTL_SEC, ctx);
    }
  }

  const hasMore = rawRows.length > limit;
  const pageRows = rawRows.slice(0, limit);
  const items = await Promise.all(pageRows.map((row) => formatPreviewCard(request, env, row)));

  return jsonResponse({
    page,
    limit,
    has_more: hasMore,
    items,
  }, 200, corsHeaders, { 'X-Kilerce-Cache': cacheStatus });
}

export async function handlePantryMatch(request, env, corsHeaders, rawBody, ctx) {
  if (!env.RECIPES_DB) {
    return jsonResponse({ error: 'RECIPES_DB binding not configured' }, 503, corsHeaders);
  }

  const body = safeJsonParse(rawBody);
  if (!body || !Array.isArray(body.pantry_tags)) {
    return jsonResponse({ error: 'Invalid JSON body: pantry_tags array required' }, 400, corsHeaders);
  }

  const pantryTags = Array.from(
    new Set(
      body.pantry_tags
        .filter((t) => typeof t === 'string' && /^[a-z0-9_]+$/.test(t.trim()))
        .map((t) => t.trim().toLowerCase()),
    ),
  ).slice(0, MAX_PANTRY_TAGS);

  if (pantryTags.length === 0) {
    return jsonResponse({ error: 'pantry_tags must contain at least one valid tag' }, 400, corsHeaders);
  }

  const pantrySet = new Set(pantryTags);
  const expiringSet = new Set(
    Array.isArray(body.expiring_tags)
      ? body.expiring_tags
          .filter((t) => typeof t === 'string')
          .map((t) => t.trim().toLowerCase())
          .slice(0, 30)
      : [],
  );

  const kilerceCat = typeof body.kilerce_category === 'string' ? body.kilerce_category.trim() : '';
  const limit = Math.max(1, Math.min(MAX_LIST_LIMIT, Number(body.limit) || 20));
  const offset = Math.max(0, Math.min(MAX_PANTRY_OFFSET, Number(body.offset) || 0));
  const nowMs = Date.now();

  const compactIndex = await loadCompactPantryIndex(env);
  if (compactIndex) {
    const pantryTagIds = new Set();
    for (const t of pantryTags) {
      const tid = compactIndex.tagIndexByName.get(t);
      if (tid !== undefined) pantryTagIds.add(tid);
    }
    const expiringTagIds = new Set();
    for (const t of expiringSet) {
      const tid = compactIndex.tagIndexByName.get(t);
      if (tid !== undefined) expiringTagIds.add(tid);
    }

    let targetCatIdx = -1;
    if (kilerceCat) {
      const resolvedCatIdx = compactIndex.catIndexByName.get(kilerceCat);
      if (resolvedCatIdx === undefined) {
        return jsonResponse({
          offset,
          limit,
          total_candidates: 0,
          has_more: false,
          items: [],
        }, 200, corsHeaders, { 'X-Kilerce-Cache': 'R2-IDX-MEM' });
      }
      targetCatIdx = resolvedCatIdx;
    }

    if (pantryTagIds.size === 0) {
      return jsonResponse({
        offset,
        limit,
        total_candidates: 0,
        has_more: false,
        items: [],
      }, 200, corsHeaders, { 'X-Kilerce-Cache': 'R2-IDX-MEM' });
    }

    const scored = [];
    const indexRecipes = compactIndex.recipes;
    for (let i = 0; i < indexRecipes.length; i++) {
      const entry = indexRecipes[i];
      if (targetCatIdx !== -1 && entry[1] !== targetCatIdx) continue;
      const reqTagIds = entry[3];
      if (!Array.isArray(reqTagIds) || reqTagIds.length === 0) continue;

      let matchedCount = 0;
      let expiringMatchedCount = 0;
      for (let j = 0; j < reqTagIds.length; j++) {
        const tid = reqTagIds[j];
        if (pantryTagIds.has(tid)) {
          matchedCount++;
          if (expiringTagIds.has(tid)) {
            expiringMatchedCount++;
          }
        }
      }
      if (matchedCount === 0) continue;

      const missingCount = reqTagIds.length - matchedCount;
      const ratio = matchedCount / reqTagIds.length;
      const qualityScore = Number(entry[2]) || 0;
      const rankScore =
        Math.round(ratio * 100) +
        expiringMatchedCount * 18 +
        (missingCount === 0 ? 40 : 0) +
        (qualityScore * 0.25);

      scored.push({ id: entry[0], rankScore, qualityScore });
    }

    scored.sort((a, b) => (b.rankScore - a.rankScore) || (b.qualityScore - a.qualityScore));
    const totalCandidates = Math.min(scored.length, MAX_PANTRY_CANDIDATES);
    const pageEntries = scored.slice(offset, Math.min(offset + limit, totalCandidates));
    const pageIds = pageEntries.map((e) => e.id);

    const { rowsById, d1FetchedCount } = await fetchPreviewRowsByIds(env, pageIds, nowMs);
    const items = [];
    for (const entry of pageEntries) {
      const row = rowsById.get(entry.id);
      if (!row) continue;
      const reqTags = parseJsonArray(row.required_tags_json);
      const matchedTags = reqTags.filter((t) => pantrySet.has(t));
      const missingTags = reqTags.filter((t) => !pantrySet.has(t));
      const expiringMatched = matchedTags.filter((t) => expiringSet.has(t));
      const ratio = reqTags.length > 0 ? matchedTags.length / reqTags.length : 1;
      items.push(
        await formatPreviewCard(request, env, row, {
          match_ratio: Number(ratio.toFixed(2)),
          matched_tags: matchedTags,
          missing_tags: missingTags,
          expiring_matched_tags: expiringMatched,
        }),
      );
    }

    const cacheStatus = d1FetchedCount === 0 ? 'R2-IDX-MEM' : 'R2-IDX-D1';
    return jsonResponse({
      offset,
      limit,
      total_candidates: totalCandidates,
      has_more: offset + limit < totalCandidates,
      items,
    }, 200, corsHeaders, { 'X-Kilerce-Cache': cacheStatus });
  }

  const queryTags = selectQueryTags(pantryTags, expiringSet);
  const cacheKey = `${kilerceCat}|${queryTags.join(',')}`;
  let cacheStatus = 'MISS';
  let rawRows = getMemCache(_memPantryCache, cacheKey, nowMs);
  let kvCacheKey = null;

  if (rawRows) {
    cacheStatus = 'HIT-MEM';
  } else {
    kvCacheKey = `pm_v1:${await sha256HexShort(cacheKey)}`;
    const kvCached = await readKvJsonCache(env, kvCacheKey);
    if (Array.isArray(kvCached)) {
      rawRows = kvCached;
      cacheStatus = 'HIT-KV';
      setMemCache(_memPantryCache, cacheKey, rawRows, MEM_CACHE_TTL_MS, MAX_MEM_PANTRY_ENTRIES, nowMs);
    }
  }

  if (!rawRows) {
    const placeholders = queryTags.map(() => '?').join(', ');
    const bindings = [...queryTags];
    let sql;

    if (kilerceCat) {
      bindings.push(kilerceCat);
      sql = `
        WITH top_candidates AS MATERIALIZED (
          SELECT ri.recipe_id,
            COUNT(DISTINCT CASE WHEN ri.is_optional = 0 THEN ri.tag END) AS matched_req_count
          FROM recipe_ingredients ri
          WHERE ri.tag IN (${placeholders})
          GROUP BY ri.recipe_id
          ORDER BY matched_req_count DESC
          LIMIT 800
        )
        SELECT ${PREVIEW_COLUMNS}, tc.matched_req_count
        FROM top_candidates tc
        INNER JOIN recipes r ON r.id = tc.recipe_id
        WHERE r.kilerce_category = ?
        ORDER BY tc.matched_req_count DESC, r.quality_score DESC
        LIMIT 160
      `;
    } else {
      sql = `
        WITH top_candidates AS MATERIALIZED (
          SELECT ri.recipe_id,
            COUNT(DISTINCT CASE WHEN ri.is_optional = 0 THEN ri.tag END) AS matched_req_count
          FROM recipe_ingredients ri
          WHERE ri.tag IN (${placeholders})
          GROUP BY ri.recipe_id
          ORDER BY matched_req_count DESC
          LIMIT 160
        )
        SELECT ${PREVIEW_COLUMNS}, tc.matched_req_count
        FROM top_candidates tc
        INNER JOIN recipes r ON r.id = tc.recipe_id
        ORDER BY tc.matched_req_count DESC, r.quality_score DESC
      `;
    }

    const result = await env.RECIPES_DB.prepare(sql).bind(...bindings).all();
    rawRows = result?.results || [];
    setMemCache(_memPantryCache, cacheKey, rawRows, MEM_CACHE_TTL_MS, MAX_MEM_PANTRY_ENTRIES, nowMs);
    if (kvCacheKey) {
      await writeKvJsonCache(env, kvCacheKey, rawRows, KV_CACHE_TTL_SEC, ctx);
    }
  }

  const candidates = rawRows.map((row) => {
    const reqTags = parseJsonArray(row.required_tags_json);
    const matchedTags = reqTags.filter((t) => pantrySet.has(t));
    const missingTags = reqTags.filter((t) => !pantrySet.has(t));
    const expiringMatched = matchedTags.filter((t) => expiringSet.has(t));
    const ratio = reqTags.length > 0 ? matchedTags.length / reqTags.length : 1;
    const rankScore =
      Math.round(ratio * 100) +
      expiringMatched.length * 18 +
      (missingTags.length === 0 ? 40 : 0) +
      ((Number(row.quality_score) || 0) * 0.25);

    return {
      row,
      reqTags,
      matchedTags,
      missingTags,
      expiringMatched,
      ratio,
      rankScore,
    };
  });

  candidates.sort((a, b) => b.rankScore - a.rankScore);
  const sliced = candidates.slice(offset, offset + limit);
  const items = await Promise.all(
    sliced.map((c) =>
      formatPreviewCard(request, env, c.row, {
        match_ratio: Number(c.ratio.toFixed(2)),
        matched_tags: c.matchedTags,
        missing_tags: c.missingTags,
        expiring_matched_tags: c.expiringMatched,
      }),
    ),
  );

  return jsonResponse({
    offset,
    limit,
    total_candidates: candidates.length,
    has_more: offset + limit < candidates.length,
    items,
  }, 200, corsHeaders, { 'X-Kilerce-Cache': cacheStatus });
}

export async function handleRecipeDetail(request, env, corsHeaders, recipeId, ctx) {
  if (!env.RECIPES_DB) {
    return jsonResponse({ error: 'RECIPES_DB binding not configured' }, 503, corsHeaders);
  }

  const appUserId = extractAppUserId(request);
  if (!appUserId) {
    return jsonResponse({ error: 'Missing or invalid X-Kilerce-User-Id header' }, 400, corsHeaders);
  }

  const cleanId = String(recipeId || '').trim();
  if (!cleanId || cleanId.length > 160 || !/^[a-zA-Z0-9_-]+$/.test(cleanId)) {
    return jsonResponse({ error: 'Invalid recipe id' }, 400, corsHeaders);
  }

  const nowMs = Date.now();
  let row = getMemCache(_memDetailCache, cleanId, nowMs);
  if (!row) {
    const kvDetailKey = `dtl_v1:${cleanId}`;
    const kvCached = await readKvJsonCache(env, kvDetailKey);
    if (kvCached && typeof kvCached === 'object' && kvCached.id === cleanId) {
      row = kvCached;
      setMemCache(_memDetailCache, cleanId, row, MEM_DETAIL_CACHE_TTL_MS, MAX_MEM_DETAIL_ENTRIES, nowMs);
    } else {
      row = await env.RECIPES_DB
        .prepare('SELECT * FROM recipes WHERE id = ?')
        .bind(cleanId)
        .first();
      if (row) {
        setMemCache(_memDetailCache, cleanId, row, MEM_DETAIL_CACHE_TTL_MS, MAX_MEM_DETAIL_ENTRIES, nowMs);
        await writeKvJsonCache(env, kvDetailKey, row, KV_CACHE_TTL_SEC, ctx);
      }
    }
  }
  if (!row) {
    return jsonResponse({ error: 'Recipe not found' }, 404, corsHeaders);
  }

  let entitlement = await resolveEntitlement(env, appUserId, nowMs);
  if (!entitlement.is_pro) {
    const ipQuota = await consumeIpFreeDetailQuota(env, request, nowMs);
    if (!ipQuota.allowed) {
      return jsonResponse({
        error: 'IP_DAILY_QUOTA_EXCEEDED',
        message: 'Günlük ücretsiz tarif görüntüleme sınırına ulaşıldı. Pro ile sınırsız erişebilirsiniz.',
        entitlement,
      }, 429, corsHeaders);
    }
    const quota = await consumeFreeDetailQuota(env, appUserId, nowMs);
    if (!quota.allowed) {
      return jsonResponse({
        error: 'PRO_REQUIRED',
        message: 'Günlük 5 ücretsiz tarif görüntüleme hakkınız doldu. 3 reklam izleyerek 3 saat Pro açabilir veya Pro plana geçebilirsiniz.',
        entitlement,
      }, 402, corsHeaders);
    }
    entitlement = await resolveEntitlement(env, appUserId, nowMs);
  }

  const imageUrl = await buildSignedMediaUrl(request, env, row.image_rel_path, nowMs);

  return jsonResponse({
    recipe: {
      id: row.id,
      source: row.source,
      title: row.title,
      subtitle: row.subtitle,
      emoji: row.emoji,
      category: row.category,
      kilerce_category: row.kilerce_category,
      region_id: row.region_id,
      prep_minutes: Number(row.prep_minutes) || 0,
      cook_minutes: Number(row.cook_minutes) || 0,
      total_minutes: Number(row.total_minutes) || 0,
      servings_count: Number(row.servings_count) || 2,
      servings_unit: row.servings_unit,
      servings_label: row.servings_label,
      difficulty: row.difficulty,
      cooking_method: row.cooking_method,
      contains_gluten: Boolean(row.contains_gluten),
      contains_lactose: Boolean(row.contains_lactose),
      is_vegan: Boolean(row.is_vegan),
      is_vegetarian: Boolean(row.is_vegetarian),
      has_margarine: Boolean(row.has_margarine),
      is_refined_sugar_free: Boolean(row.is_refined_sugar_free),
      is_healthy_clean: Boolean(row.is_healthy_clean),
      base_health_score: Number(row.base_health_score) || 0,
      quality_score: Number(row.quality_score) || 0,
      clean_label_badges: parseJsonArray(row.clean_label_badges_json),
      diet_tags: parseJsonArray(row.diet_tags_json),
      meal_slots: parseJsonArray(row.meal_slots_json),
      required_tags: parseJsonArray(row.required_tags_json),
      optional_tags: parseJsonArray(row.optional_tags_json),
      ingredients: parseJsonArray(row.ingredients_json),
      steps: parseJsonArray(row.steps_json),
      image_rel_path: row.image_rel_path,
      image_url: imageUrl,
    },
    entitlement,
  }, 200, corsHeaders);
}

export async function handleSignedMedia(request, env, corsHeaders, encodedRelPath) {
  if (!env.RECIPE_MEDIA) {
    return jsonResponse({ error: 'RECIPE_MEDIA bucket not configured' }, 503, corsHeaders);
  }

  let relPath;
  try {
    relPath = encodedRelPath
      .split('/')
      .map((seg) => decodeURIComponent(seg))
      .join('/');
  } catch (err) {
    return jsonResponse({ error: `Malformed media path: ${err.name}` }, 400, corsHeaders);
  }

  if (
    !relPath.startsWith('photo_webp_v2/') ||
    !relPath.endsWith('.webp') ||
    relPath.includes('..') ||
    relPath.includes('\\')
  ) {
    return jsonResponse({ error: 'Invalid media path' }, 400, corsHeaders);
  }

  const url = new URL(request.url);
  const expSec = Number(url.searchParams.get('exp'));
  const sigHex = url.searchParams.get('sig') || '';
  const mediaSecret = env.MEDIA_SIGNING_SECRET || env.HMAC_SECRET || '';

  const tokenOk = await verifyMediaToken(relPath, expSec, sigHex, mediaSecret);
  if (!tokenOk) {
    return jsonResponse({ error: 'Invalid or expired media signature' }, 403, corsHeaders);
  }

  const object = await env.RECIPE_MEDIA.get(relPath);
  if (!object) {
    return jsonResponse({ error: 'Media not found' }, 404, corsHeaders);
  }

  const headers = new Headers(corsHeaders);
  headers.set('Content-Type', object.httpMetadata?.contentType || 'image/webp');
  headers.set('Cache-Control', 'private, max-age=86400');
  if (object.httpEtag) {
    headers.set('ETag', object.httpEtag);
  }

  return new Response(object.body, { status: 200, headers });
}

export async function handleSignMediaBatch(request, env, corsHeaders, rawBody) {
  const body = safeJsonParse(rawBody);
  const rawPaths = Array.isArray(body?.paths) ? body.paths : null;
  if (!rawPaths) {
    return jsonResponse({ error: 'Invalid JSON body: paths array required' }, 400, corsHeaders);
  }

  const validPaths = Array.from(
    new Set(
      rawPaths
        .filter((p) => typeof p === 'string')
        .map((p) => p.trim())
        .filter(
          (p) =>
            p.startsWith('photo_webp_v2/') &&
            p.endsWith('.webp') &&
            !p.includes('..') &&
            !p.includes('\\'),
        ),
    ),
  ).slice(0, 120);

  const nowMs = Date.now();
  const entries = await Promise.all(
    validPaths.map(async (relPath) => [
      relPath,
      await buildSignedMediaUrl(request, env, relPath, nowMs),
    ]),
  );

  return jsonResponse({
    urls: Object.fromEntries(entries),
  }, 200, corsHeaders);
}
