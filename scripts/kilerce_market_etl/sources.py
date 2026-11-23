"""Live HTTP discovery, verification, and TGK enrichment strategies (OCP/SRP/DIP).

Implements:
- PooledHttpClient (HttpClientProtocol with bounded LRU+TTL cache, timeouts, retries)
- OpenFoodFactsSearchSource (search.openfoodfacts.org/search?q=...&page_size=100)
- MarketFiyatiVerifierSource (api.marketfiyati.org.tr/api/v2/{nearest,searchByIdentity,search})
- MigrosRestEnrichmentStrategy (migros.com.tr/rest/{search/screens/products,products/screens/{id}})
- CepteSokEnrichmentStrategy (sokmarket.com.tr TGK künyesi & RSC nutritionFacts)
- OpenFoodFactsProductBatchStrategy (world.openfoodfacts.org/api/v2/search?code=... batch)
"""

from __future__ import annotations

import html
import json
import logging
import os
import re
import statistics
import threading
import time
import urllib.parse
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Any, Mapping, Sequence

import requests
from requests.adapters import HTTPAdapter

from .contracts import (
    BoundedTtlLruCache,
    DiscoverySourceProtocol,
    EnrichmentStrategyProtocol,
    HttpClientProtocol,
    MarketIdentityInfo,
    MarketVerifierProtocol,
    Nutriments100g,
    RawDiscoveryCandidate,
    TgkEnrichmentInfo,
)
from .validators import (
    clean_ingredients_text,
    is_valid_atwater_nutrition,
    is_valid_brand_name,
    is_valid_gs1_barcode,
    is_valid_product_name,
    normalize_ascii_tr,
    normalize_nutriments,
    parse_quantity_to_base_unit,
    validate_full_ingredients,
)

logger = logging.getLogger(__name__)

# Mandatory GS1 prefixes, private labels, chain labels, and national brands
BIM_BRANDS: tuple[str, ...] = (
    "Dost",
    "Aknaz",
    "Efsane",
    "Saban",
    "Sole",
    "Yurdum",
    "Simbat",
    "Peripella",
    "Derya",
)
A101_BRANDS: tuple[str, ...] = (
    "Birşah",
    "Tarabya",
    "Peynes",
    "Ahir",
    "Vera",
    "Ovadan",
    "Çokça",
    "Bendo",
)
SOK_BRANDS: tuple[str, ...] = (
    "Mis",
    "Piyale",
    "Lio",
    "Evin",
    "Amigo",
    "Karmen",
)
CHAIN_BRANDS: tuple[str, ...] = (
    "Migros",
    "Carrefour",
    "Tarım Kredi",
)
NATIONAL_BRANDS: tuple[str, ...] = (
    "Ülker",
    "Eti",
    "Torku",
    "Sütaş",
    "Pınar",
    "Beypazarı",
    "Dimes",
    "Züber",
    "Çaykur",
    "İçim",
    "Tat",
    "Duru",
    "Yayla",
    "Filiz",
    "Tadım",
    "Uludağ",
    "Doğanay",
)

NON_FOOD_CATEGORY_KEYWORDS: tuple[str, ...] = (
    "pet-food",
    "cat-food",
    "dog-food",
    "cosmetics",
    "shampoos",
    "soaps",
    "detergents",
    "cleaning",
    "hygiene",
    "toilet-paper",
    "tobacco",
    "cigarettes",
    "batteries",
)

MARKET_CHAIN_CANONICAL_MAP: dict[str, str] = {
    "bim": "BİM",
    "a101": "A101",
    "sok": "ŞOK",
    "şok": "ŞOK",
    "ceptesok": "ŞOK",
    "migros": "Migros",
    "carrefour": "CarrefourSA",
    "carrefoursa": "CarrefourSA",
    "tarim_kredi": "Tarım Kredi",
    "tarım kredi": "Tarım Kredi",
    "tarim kredi": "Tarım Kredi",
    "koop": "Tarım Kredi",
    "hakmar": "Hakmar",
}

CONFLICT_VARIANT_GROUPS: tuple[frozenset[str], ...] = (
    frozenset({"tam yagli", "yarim yagli", "yagsiz", "light"}),
    frozenset({"kakaolu", "cilekli", "muzlu", "vanilyali", "sade", "kahveli"}),
    frozenset({"acili", "tatli"}),
)

SINGLE_CONFLICT_FLAGS: tuple[str, ...] = (
    "laktozsuz",
    "sekersiz",
    "glutensiz",
    "organik",
    "keciboynuzu",
    "findikli",
    "fistikli",
    "bademli",
    "cevizli",
)

STOP_TOKENS: frozenset[str] = frozenset(
    {
        "g",
        "gr",
        "gram",
        "kg",
        "ml",
        "l",
        "lt",
        "cl",
        "adet",
        "paket",
        "kutu",
        "sise",
        "pet",
        "cam",
        "ve",
        "ile",
        "icin",
        "yeni",
        "boy",
        "ekonomik",
    }
)


def _match_product_similarity(
    target_brand: str,
    target_name: str,
    target_qty_str: str,
    cand_brand: str,
    cand_name: str,
    cand_qty_str: str = "",
) -> float:
    """Compute strict 0..1 similarity score ensuring brand, quantity, & variant alignment."""
    tb = normalize_ascii_tr(target_brand)
    cb = normalize_ascii_tr(cand_brand)
    tn = normalize_ascii_tr(target_name)
    cn = normalize_ascii_tr(cand_name)

    if not tn or not cn:
        return 0.0

    # Brand gate
    if tb and cb:
        if tb not in cb and cb not in tb and tb.split()[0] != cb.split()[0]:
            return 0.0
    elif tb and tb not in cn:
        return 0.0

    # Quantity gate (prevent matching 200ml to 1L or 60g to 80g)
    q1 = parse_quantity_to_base_unit(target_qty_str) or parse_quantity_to_base_unit(target_name)
    q2 = parse_quantity_to_base_unit(cand_qty_str) or parse_quantity_to_base_unit(cand_name)
    if q1 is not None and q2 is not None and q1[1] == q2[1]:
        ratio = min(q1[0], q2[0]) / max(q1[0], q2[0])
        if ratio < 0.88:
            return 0.0

    # Variant conflict gate
    for group in CONFLICT_VARIANT_GROUPS:
        t_hits = {v for v in group if v in tn}
        c_hits = {v for v in group if v in cn}
        if t_hits and c_hits and t_hits.isdisjoint(c_hits):
            return 0.0

    for flag in SINGLE_CONFLICT_FLAGS:
        if (flag in tn) != (flag in cn):
            return 0.0

    brand_tokens = set(tb.split()) | set(cb.split())
    t_tokens = {
        tok
        for tok in tn.split()
        if len(tok) >= 2 and not tok.isdigit() and tok not in STOP_TOKENS and tok not in brand_tokens
    }
    c_tokens = {
        tok
        for tok in cn.split()
        if len(tok) >= 2 and not tok.isdigit() and tok not in STOP_TOKENS and tok not in brand_tokens
    }
    if not t_tokens or not c_tokens:
        return 0.65 if (tb and tb == cb and q1 is not None and q1 == q2) else 0.0

    inter = len(t_tokens & c_tokens)
    if inter == 0:
        return 0.0
    union = len(t_tokens | c_tokens)
    recall = inter / min(len(t_tokens), len(c_tokens))
    jaccard = inter / union
    return 0.55 * recall + 0.45 * jaccard


class PooledHttpClient(HttpClientProtocol):
    """Thread-safe keep-alive HTTP client with bounded TTL-LRU cache and retries."""

    def __init__(
        self,
        pool_maxsize: int = 32,
        cache_maxsize: int = 4096,
        cache_ttl_seconds: float = 3600.0,
        max_retries: int = 2,
    ) -> None:
        self._session = requests.Session()
        adapter = HTTPAdapter(pool_connections=pool_maxsize, pool_maxsize=pool_maxsize)
        self._session.mount("https://", adapter)
        self._session.mount("http://", adapter)
        self._session.headers.update(
            {
                "User-Agent": (
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
                ),
                "Accept-Language": "tr-TR,tr;q=0.9,en-US;q=0.7,en;q=0.6",
            }
        )
        self._cache: BoundedTtlLruCache[str, Any] = BoundedTtlLruCache(
            maxsize=cache_maxsize, ttl_seconds=cache_ttl_seconds
        )
        self._max_retries = max_retries
        self._closed = False

    def _build_cache_key(
        self, kind: str, url: str, params: Mapping[str, Any] | None
    ) -> str:
        if not params:
            return f"{kind}:{url}"
        encoded = urllib.parse.urlencode(sorted((str(k), str(v)) for k, v in params.items()))
        return f"{kind}:{url}?{encoded}"

    def get_json(
        self,
        url: str,
        *,
        params: Mapping[str, Any] | None = None,
        headers: Mapping[str, str] | None = None,
        timeout: tuple[float, float] = (5.0, 12.0),
        use_cache: bool = True,
    ) -> Any | None:
        if self._closed:
            return None
        cache_key = self._build_cache_key("json", url, params)
        if use_cache:
            hit, cached = self._cache.get(cache_key)
            if hit:
                return cached

        req_headers = {"Accept": "application/json"}
        if headers:
            req_headers.update(headers)

        for attempt in range(self._max_retries + 1):
            try:
                resp = self._session.get(
                    url, params=params, headers=req_headers, timeout=timeout
                )
                if resp.status_code == 200:
                    data = resp.json()
                    if use_cache:
                        self._cache.set(cache_key, data)
                    return data
                if resp.status_code in (429, 500, 502, 503, 504) and attempt < self._max_retries:
                    time.sleep(0.8 * (attempt + 1))
                    continue
                return None
            except (requests.RequestException, ValueError) as exc:
                logger.debug("GET JSON failed (%s, attempt %d): %s", url, attempt, exc)
                if attempt < self._max_retries:
                    time.sleep(0.6 * (attempt + 1))
        return None

    def post_json(
        self,
        url: str,
        *,
        payload: Mapping[str, Any],
        headers: Mapping[str, str] | None = None,
        timeout: tuple[float, float] = (5.0, 12.0),
    ) -> Any | None:
        if self._closed:
            return None
        req_headers = {
            "Accept": "application/json",
            "Content-Type": "application/json",
        }
        if headers:
            req_headers.update(headers)

        for attempt in range(self._max_retries + 1):
            try:
                resp = self._session.post(
                    url, json=dict(payload), headers=req_headers, timeout=timeout
                )
                if resp.status_code == 200:
                    return resp.json()
                if resp.status_code in (429, 500, 502, 503, 504) and attempt < self._max_retries:
                    time.sleep(0.7 * (attempt + 1))
                    continue
                return None
            except (requests.RequestException, ValueError) as exc:
                logger.debug("POST JSON failed (%s, attempt %d): %s", url, attempt, exc)
                if attempt < self._max_retries:
                    time.sleep(0.5 * (attempt + 1))
        return None

    def get_text(
        self,
        url: str,
        *,
        params: Mapping[str, Any] | None = None,
        headers: Mapping[str, str] | None = None,
        timeout: tuple[float, float] = (5.0, 12.0),
        use_cache: bool = True,
    ) -> str | None:
        if self._closed:
            return None
        cache_key = self._build_cache_key("text", url, params)
        if use_cache:
            hit, cached = self._cache.get(cache_key)
            if hit and isinstance(cached, str):
                return cached

        req_headers = {"Accept": "text/html,application/xhtml+xml,*/*;q=0.8"}
        if headers:
            req_headers.update(headers)

        for attempt in range(self._max_retries + 1):
            try:
                resp = self._session.get(
                    url, params=params, headers=req_headers, timeout=timeout
                )
                if resp.status_code == 200:
                    text = resp.text
                    if use_cache:
                        self._cache.set(cache_key, text)
                    return text
                if resp.status_code in (429, 500, 502, 503, 504) and attempt < self._max_retries:
                    time.sleep(0.8 * (attempt + 1))
                    continue
                return None
            except requests.RequestException as exc:
                logger.debug("GET TEXT failed (%s, attempt %d): %s", url, attempt, exc)
                if attempt < self._max_retries:
                    time.sleep(0.6 * (attempt + 1))
        return None

    def close(self) -> None:
        if not self._closed:
            self._closed = True
            self._cache.clear()
            self._session.close()


class OpenFoodFactsSearchSource(DiscoverySourceProtocol):
    """Discovers genuine GS1 barcodes via search.openfoodfacts.org/search?q=...&page_size=100."""

    SEARCH_URL = "https://search.openfoodfacts.org/search"
    OFF_HEADERS = {"User-Agent": "OrganicScoreETL/2.0 (contact@organicscore.app)"}

    def __init__(
        self,
        http_client: HttpClientProtocol,
        seed_snapshot_path: str | None = None,
        max_workers: int = 6,
    ) -> None:
        self._http = http_client
        self._seed_snapshot_path = seed_snapshot_path
        self._max_workers = max_workers

    @property
    def source_name(self) -> str:
        return "openfoodfacts_search"

    def _build_query_plan(self) -> list[tuple[str, int]]:
        plan: list[tuple[str, int]] = [
            # GS1 retail private-label prefixes
            ("code:8695077*", 5),  # BİM
            ("code:8699118*", 2),  # A101
            ("code:8682214*", 1),  # ŞOK
            # Completed-ingredients Turkish GS1 pools (high yield)
            ('code:869* AND states_tags:"en:ingredients-completed"', 17),
            ('code:868* AND states_tags:"en:ingredients-completed"', 4),
            ('countries_tags:"en:turkey" AND states_tags:"en:ingredients-completed"', 6),
            # General Turkey catalog
            ('countries_tags:"en:turkey"', 12),
        ]
        all_brands = (
            BIM_BRANDS
            + A101_BRANDS
            + SOK_BRANDS
            + CHAIN_BRANDS
            + NATIONAL_BRANDS
        )
        for brand in all_brands:
            plan.append((brand, 2))

        global_tr_shelf_brands = (
            "coca-cola",
            "nestle",
            "milka",
            "ferrero",
            "kinder",
            "haribo",
            "barilla",
            "knorr",
            "dr-oetker",
            "danone",
            "activia",
            "lipton",
            "pringles",
            "loacker",
            "lindt",
            "heinz",
        )
        for btag in global_tr_shelf_brands:
            plan.append((f'brands_tags:"{btag}" AND states_tags:"en:ingredients-completed"', 2))
        return plan

    def _fetch_query_page(self, query: str, page: int) -> list[dict[str, Any]]:
        data = self._http.get_json(
            self.SEARCH_URL,
            params={"q": query, "page_size": 100, "page": page},
            headers=self.OFF_HEADERS,
            timeout=(6.0, 15.0),
        )
        if not isinstance(data, Mapping):
            return []
        hits = data.get("hits")
        return hits if isinstance(hits, list) else []

    @staticmethod
    def _is_non_food_hit(hit: Mapping[str, Any]) -> bool:
        cats = hit.get("categories_tags") or []
        if not isinstance(cats, list):
            return False
        joined = " ".join(str(c).lower() for c in cats)
        return any(kw in joined for kw in NON_FOOD_CATEGORY_KEYWORDS)

    @staticmethod
    def _extract_hit_candidate(hit: Mapping[str, Any]) -> RawDiscoveryCandidate | None:
        bc = str(hit.get("code") or "").strip()
        if not is_valid_gs1_barcode(bc):
            return None
        if OpenFoodFactsSearchSource._is_non_food_hit(hit):
            return None

        name = str(
            hit.get("product_name_tr")
            or hit.get("product_name")
            or hit.get("product_name_en")
            or ""
        ).strip()

        raw_brands = hit.get("brands")
        brand = ""
        if isinstance(raw_brands, list) and raw_brands:
            brand = str(raw_brands[0]).split(",")[0].strip()
        elif isinstance(raw_brands, str) and raw_brands.strip():
            brand = raw_brands.split(",")[0].strip()

        qty = str(hit.get("quantity") or "").strip()
        nutr = hit.get("nutriments")
        nutr_dict = dict(nutr) if isinstance(nutr, Mapping) else {}

        allergens_tags = hit.get("allergens_tags")
        allergens = ""
        if isinstance(allergens_tags, list) and allergens_tags:
            allergens = ", ".join(str(a) for a in allergens_tags)

        raw_stores = hit.get("stores")
        stores_list: list[str] = []
        if isinstance(raw_stores, list):
            stores_list = [str(s).strip() for s in raw_stores if str(s).strip()]
        elif isinstance(raw_stores, str) and raw_stores.strip():
            stores_list = [s.strip() for s in raw_stores.split(",") if s.strip()]

        states_tags = hit.get("states_tags") or []
        has_completed_ing = (
            isinstance(states_tags, list)
            and "en:ingredients-completed" in states_tags
        )

        nova_val = hit.get("nova_group")
        nova_int = int(nova_val) if isinstance(nova_val, (int, float)) and 1 <= int(nova_val) <= 4 else None

        return RawDiscoveryCandidate(
            barcode=bc,
            product_name=name,
            brand=brand,
            net_quantity=qty,
            nutriments_raw=nutr_dict,
            allergens=allergens,
            nova_group=nova_int,
            stores=tuple(stores_list),
            has_completed_ingredients_tag=has_completed_ing,
            source_tag="openfoodfacts_search",
        )

    def discover(self) -> list[RawDiscoveryCandidate]:
        query_plan = self._build_query_plan()
        tasks: list[tuple[str, int]] = []
        for query, max_pages in query_plan:
            for page in range(1, max_pages + 1):
                tasks.append((query, page))

        by_barcode: dict[str, RawDiscoveryCandidate] = {}

        with ThreadPoolExecutor(max_workers=self._max_workers) as executor:
            future_map = {
                executor.submit(self._fetch_query_page, q, p): (q, p)
                for q, p in tasks
            }
            for fut in as_completed(future_map):
                try:
                    hits = fut.result()
                except Exception as exc:
                    logger.warning("OFF search worker failed: %s", exc)
                    continue
                for hit in hits:
                    if not isinstance(hit, Mapping):
                        continue
                    cand = self._extract_hit_candidate(hit)
                    if cand is None:
                        continue
                    existing = by_barcode.get(cand.barcode)
                    if existing is None:
                        by_barcode[cand.barcode] = cand
                    else:
                        if not existing.product_name and cand.product_name:
                            existing.product_name = cand.product_name
                        if not existing.brand and cand.brand:
                            existing.brand = cand.brand
                        if not existing.nutriments_raw and cand.nutriments_raw:
                            existing.nutriments_raw = cand.nutriments_raw
                        if cand.has_completed_ingredients_tag:
                            existing.has_completed_ingredients_tag = True

        # Also preserve valid real GS1 barcodes from existing snapshot for re-verification
        if self._seed_snapshot_path and os.path.isfile(self._seed_snapshot_path):
            try:
                with open(self._seed_snapshot_path, "r", encoding="utf-8") as fh:
                    old_items = json.load(fh)
                if isinstance(old_items, list):
                    for row in old_items:
                        if not isinstance(row, Mapping):
                            continue
                        bc = str(row.get("barcode") or "").strip()
                        if is_valid_gs1_barcode(bc) and bc not in by_barcode:
                            by_barcode[bc] = RawDiscoveryCandidate(
                                barcode=bc,
                                product_name=str(row.get("product_name") or "").strip(),
                                brand=str(row.get("brand") or "").strip(),
                                has_completed_ingredients_tag=True,
                                source_tag="openfoodfacts_search",
                            )
            except (OSError, ValueError) as exc:
                logger.warning("Seed snapshot read skipped: %s", exc)

        return list(by_barcode.values())

    def close(self) -> None:
        return None


class MarketFiyatiVerifierSource(MarketVerifierProtocol):
    """TÜBİTAK MarketFiyatı official barcode, chain, weight, and shelf price verifier."""

    BASE_URL = "https://api.marketfiyati.org.tr/api/v2"
    METRO_COORDINATES: tuple[tuple[float, float], ...] = (
        (41.0082, 28.9784),  # İstanbul Avrupa (Fatih/Eminönü)
        (40.9901, 29.0292),  # İstanbul Anadolu (Kadıköy)
        (39.9208, 32.8541),  # Ankara (Çankaya/Kızılay)
        (38.4237, 27.1428),  # İzmir (Konak/Alsancak)
    )

    def __init__(
        self,
        http_client: HttpClientProtocol,
        max_workers: int = 8,
        max_identity_lookups: int = 1600,
        max_keyword_fallbacks: int = 180,
    ) -> None:
        self._http = http_client
        self._max_workers = max_workers
        self._max_identity_lookups = max_identity_lookups
        self._max_keyword_fallbacks = max_keyword_fallbacks
        self._depots: list[str] = []

    @property
    def source_name(self) -> str:
        return "tubitak_marketfiyati"

    def _load_depots(self) -> list[str]:
        if self._depots:
            return self._depots
        per_market_counts: dict[str, int] = {}
        depots: list[str] = []
        seen_ids: set[str] = set()

        for lat, lon in self.METRO_COORDINATES:
            resp = self._http.post_json(
                f"{self.BASE_URL}/nearest",
                payload={"latitude": lat, "longitude": lon, "distance": 12},
                timeout=(5.0, 10.0),
            )
            if not isinstance(resp, list):
                continue
            for item in resp:
                if not isinstance(item, Mapping):
                    continue
                depot_id = str(item.get("id") or "").strip()
                market = str(item.get("marketName") or "").strip().lower()
                if not depot_id or depot_id in seen_ids:
                    continue
                # Keep up to 10 depots per chain across İstanbul/Ankara/İzmir (~65 depots total)
                if per_market_counts.get(market, 0) >= 10:
                    continue
                seen_ids.add(depot_id)
                depots.append(depot_id)
                per_market_counts[market] = per_market_counts.get(market, 0) + 1

        self._depots = depots
        return depots

    @staticmethod
    def _parse_mf_content_item(
        barcode: str, item: Mapping[str, Any]
    ) -> MarketIdentityInfo | None:
        title = str(item.get("title") or "").strip()
        brand = str(item.get("brand") or "").strip()
        qty = str(item.get("refinedVolumeOrWeight") or "").strip()

        depot_infos = item.get("productDepotInfoList")
        prices: list[float] = []
        chains: list[str] = []
        seen_chains: set[str] = set()

        if isinstance(depot_infos, list):
            for dp in depot_infos:
                if not isinstance(dp, Mapping):
                    continue
                raw_price = dp.get("price")
                if isinstance(raw_price, (int, float)) and 0.5 <= float(raw_price) <= 50000.0:
                    prices.append(float(raw_price))
                raw_market = str(dp.get("marketAdi") or "").strip().lower()
                if not raw_market:
                    depot_id = str(dp.get("depotId") or "").strip().lower()
                    raw_market = depot_id.split("-")[0] if "-" in depot_id else ""
                canonical = MARKET_CHAIN_CANONICAL_MAP.get(raw_market)
                if canonical and canonical not in seen_chains:
                    seen_chains.add(canonical)
                    chains.append(canonical)

        if not title and not chains:
            return None

        ref_price = round(statistics.median(prices), 2) if prices else None
        return MarketIdentityInfo(
            barcode=barcode,
            official_name=title,
            official_brand=brand,
            net_quantity=qty,
            reference_price_try=ref_price,
            market_chains=tuple(chains),
            source_tag="tubitak_marketfiyati",
        )

    def _query_by_barcode(self, barcode: str, depots: list[str]) -> MarketIdentityInfo | None:
        resp = self._http.post_json(
            f"{self.BASE_URL}/searchByIdentity",
            payload={
                "identity": barcode,
                "identityType": "barcode",
                "depots": depots,
            },
            timeout=(5.0, 10.0),
        )
        if not isinstance(resp, Mapping):
            return None
        content = resp.get("content")
        if not isinstance(content, list) or not content:
            return None
        first = content[0]
        if not isinstance(first, Mapping):
            return None
        return self._parse_mf_content_item(barcode, first)

    def _query_by_keywords(
        self, candidate: RawDiscoveryCandidate, depots: list[str]
    ) -> MarketIdentityInfo | None:
        if not candidate.product_name or not candidate.brand:
            return None
        kw = f"{candidate.brand} {candidate.product_name}".strip()
        resp = self._http.post_json(
            f"{self.BASE_URL}/search",
            payload={"keywords": kw, "pages": 0, "size": 5, "depots": depots},
            timeout=(5.0, 10.0),
        )
        if not isinstance(resp, Mapping):
            return None
        content = resp.get("content")
        if not isinstance(content, list) or not content:
            return None

        best_item: Mapping[str, Any] | None = None
        best_score = 0.0
        for row in content:
            if not isinstance(row, Mapping):
                continue
            sim = _match_product_similarity(
                target_brand=candidate.brand,
                target_name=candidate.product_name,
                target_qty_str=candidate.net_quantity,
                cand_brand=str(row.get("brand") or ""),
                cand_name=str(row.get("title") or ""),
                cand_qty_str=str(row.get("refinedVolumeOrWeight") or ""),
            )
            if sim > best_score:
                best_score = sim
                best_item = row

        if best_item is not None and best_score >= 0.72:
            return self._parse_mf_content_item(candidate.barcode, best_item)
        return None

    def verify_candidates(
        self, candidates: Sequence[RawDiscoveryCandidate]
    ) -> dict[str, MarketIdentityInfo]:
        depots = self._load_depots()
        if not depots:
            logger.warning("MarketFiyatı returned 0 depots; skipping verification.")
            return {}

        verified: dict[str, MarketIdentityInfo] = {}
        identity_targets = sorted(
            candidates,
            key=lambda c: (
                0 if c.barcode.startswith(("868", "869")) else 1,
                0 if c.has_completed_ingredients_tag else 1,
            ),
        )[: self._max_identity_lookups]

        with ThreadPoolExecutor(max_workers=self._max_workers) as executor:
            future_map = {
                executor.submit(self._query_by_barcode, cand.barcode, depots): cand
                for cand in identity_targets
            }
            for fut in as_completed(future_map):
                cand = future_map[fut]
                try:
                    info = fut.result()
                except Exception as exc:
                    logger.debug("MF identity error for %s: %s", cand.barcode, exc)
                    continue
                if info is not None:
                    verified[cand.barcode] = info

            # Keyword `/api/v2/search` fallback for Turkish-brand items missing barcode hit
            fallback_cands = [
                cand
                for cand in candidates
                if cand.barcode not in verified
                and is_valid_brand_name(cand.brand)
                and is_valid_product_name(cand.product_name)
                and cand.barcode.startswith(("868", "869"))
            ][: self._max_keyword_fallbacks]

            kw_futures = {
                executor.submit(self._query_by_keywords, cand, depots): cand
                for cand in fallback_cands
            }
            for fut in as_completed(kw_futures):
                cand = kw_futures[fut]
                try:
                    info = fut.result()
                except Exception as exc:
                    logger.debug("MF keyword error for %s: %s", cand.barcode, exc)
                    continue
                if info is not None:
                    verified[cand.barcode] = info

        return verified

    def close(self) -> None:
        return None


class MigrosRestEnrichmentStrategy(EnrichmentStrategyProtocol):
    """Migros Sanal Market PWA REST TGK enrichment (`MAIN`, `NUTRITIONAL`, `LEGAL`, `description`)."""

    SEARCH_URL = "https://www.migros.com.tr/rest/search/screens/products"
    DETAIL_URL_FMT = "https://www.migros.com.tr/rest/products/screens/{product_id}"
    MIGROS_HEADERS = {
        "X-PWA": "true",
        "X-FORWARDED-REST": "true",
        "Referer": "https://www.migros.com.tr/",
    }
    EXCLUSIVE_OTHER_CHAINS = frozenset(
        {normalize_ascii_tr(b) for b in (BIM_BRANDS + A101_BRANDS + SOK_BRANDS)}
    )

    def __init__(
        self,
        http_client: HttpClientProtocol,
        max_workers: int = 8,
        max_on_demand_searches: int = 380,
    ) -> None:
        self._http = http_client
        self._max_workers = max_workers
        self._max_on_demand_searches = max_on_demand_searches
        self._catalog_by_brand: dict[str, list[dict[str, Any]]] = {}
        self._enriched_by_barcode: dict[str, TgkEnrichmentInfo] = {}
        self._detail_cache: BoundedTtlLruCache[int, TgkEnrichmentInfo] = BoundedTtlLruCache(
            maxsize=3000, ttl_seconds=3600.0
        )

    @property
    def source_name(self) -> str:
        return "migros_rest_tgk"

    @property
    def priority(self) -> int:
        return 10

    def _search_migros_page(self, query: str, page: int = 1) -> list[dict[str, Any]]:
        params: dict[str, Any] = {"q": query}
        if page > 1:
            params["sayfa"] = page
        resp = self._http.get_json(
            self.SEARCH_URL,
            params=params,
            headers=self.MIGROS_HEADERS,
            timeout=(5.0, 12.0),
        )
        if not isinstance(resp, Mapping) or not resp.get("successful"):
            return []
        data = resp.get("data")
        if not isinstance(data, Mapping):
            return []
        search_info = data.get("searchInfo")
        if not isinstance(search_info, Mapping):
            return []
        infos = search_info.get("storeProductInfos")
        return [row for row in infos if isinstance(row, dict)] if isinstance(infos, list) else []

    @staticmethod
    def _extract_html_field(desc_html: str, label: str) -> str:
        if not desc_html:
            return ""
        pattern = re.compile(
            rf"<strong>\s*{re.escape(label)}\s*</strong>\s*(?:<br\s*/?>)?\s*(.*?)\s*</p>",
            re.IGNORECASE | re.DOTALL,
        )
        match = pattern.search(desc_html)
        if not match:
            return ""
        raw = html.unescape(re.sub(r"<[^>]+>", " ", match.group(1)))
        return re.sub(r"\s+", " ", raw).strip()

    def _fetch_migros_detail(self, product_id: int) -> TgkEnrichmentInfo | None:
        hit, cached = self._detail_cache.get(product_id)
        if hit and cached is not None:
            return cached

        resp = self._http.get_json(
            self.DETAIL_URL_FMT.format(product_id=product_id),
            headers=self.MIGROS_HEADERS,
            timeout=(5.0, 12.0),
        )
        if not isinstance(resp, Mapping) or not resp.get("successful"):
            return None
        data = resp.get("data")
        if not isinstance(data, Mapping):
            return None
        dto = data.get("storeProductInfoDTO")
        if not isinstance(dto, Mapping):
            return None

        prop_map = dto.get("propertyInfosMap")
        prop_map = prop_map if isinstance(prop_map, Mapping) else {}

        main_props = prop_map.get("MAIN")
        nutr_props = prop_map.get("NUTRITIONAL")
        legal_props = prop_map.get("LEGAL")

        ingredients = ""
        allergens = ""
        net_qty = ""
        supplier_name = ""
        supplier_reg = ""

        if isinstance(main_props, list):
            for prop in main_props:
                if not isinstance(prop, Mapping):
                    continue
                pname = str(prop.get("name") or "").strip().lower()
                cid = str(prop.get("customId") or "").strip()
                pval = str(prop.get("value") or "").strip()
                if not pval:
                    continue
                if "içindekiler" in pname or "icindekiler" in pname:
                    ingredients = clean_ingredients_text(pval)
                elif "alerjen" in pname:
                    allergens = re.sub(r"\s+", " ", html.unescape(pval)).strip()
                elif cid == "netKg" or "net miktar" in pname:
                    net_qty = f"{pval} g" if pval.isdigit() else pval
                elif cid == "productSupplier" or ("işletmeci" in pname and "numara" not in pname and "adres" not in pname):
                    supplier_name = pval
                elif cid == "productSupplierId" or "numarası" in pname:
                    supplier_reg = pval

        if isinstance(legal_props, list) and not supplier_reg:
            for prop in legal_props:
                if not isinstance(prop, Mapping):
                    continue
                pname = str(prop.get("name") or "").strip().lower()
                pval = str(prop.get("value") or "").strip()
                if pval and ("kayıt" in pname or "onay" in pname):
                    supplier_reg = pval

        desc_html = str(dto.get("description") or "")
        if not ingredients and desc_html:
            ingredients = clean_ingredients_text(
                self._extract_html_field(desc_html, "İçindekiler")
            )
        if not allergens and desc_html:
            allergens = self._extract_html_field(desc_html, "Alerjen Uyarısı")

        nutr_raw: dict[str, Any] = {}
        if isinstance(nutr_props, list):
            for prop in nutr_props:
                if not isinstance(prop, Mapping):
                    continue
                cid = str(prop.get("customId") or "").strip()
                pname = str(prop.get("name") or "").strip().lower()
                pval = prop.get("value")
                if pval is None:
                    continue
                if cid == "energyKcal" or "enerji (kcal)" in pname:
                    nutr_raw["energy_kcal"] = pval
                elif cid == "energyKj" or "enerji (kj)" in pname:
                    nutr_raw["energy_kj"] = pval
                elif cid == "fat" or pname == "yağ (g)":
                    nutr_raw["fat_g"] = pval
                elif cid == "saturatedFat" or "doymuş" in pname:
                    nutr_raw["saturated_fat_g"] = pval
                elif cid == "carbohydrate" or "karbonhidrat" in pname:
                    nutr_raw["carbs_g"] = pval
                elif cid in ("glucose", "sugar", "sugars") or "şeker" in pname:
                    nutr_raw["sugars_g"] = pval
                elif cid in ("dietaryFiber", "fiber") or "lif" in pname:
                    nutr_raw["fiber_g"] = pval
                elif cid == "protein" or "protein" in pname:
                    nutr_raw["protein_g"] = pval
                elif cid == "salt" or "tuz" in pname:
                    nutr_raw["salt_g"] = pval

        nutriments = (
            normalize_nutriments(nutr_raw)
            if is_valid_atwater_nutrition(nutr_raw)
            else None
        )

        producer_full = supplier_name
        if supplier_name and supplier_reg:
            producer_full = f"{supplier_name} (Kayıt No: {supplier_reg})"

        shown_price = dto.get("shownPrice")
        price_try = (
            round(float(shown_price) / 100.0, 2)
            if isinstance(shown_price, (int, float)) and float(shown_price) > 0
            else None
        )

        brand_obj = dto.get("brand")
        official_brand = (
            str(brand_obj.get("name") or "").strip()
            if isinstance(brand_obj, Mapping)
            else ""
        )
        official_name = str(dto.get("name") or "").strip()

        info = TgkEnrichmentInfo(
            ingredients_text=ingredients if validate_full_ingredients(ingredients) else "",
            nutriments=nutriments,
            allergens=allergens,
            net_quantity=net_qty,
            producer_legal_name=producer_full,
            reference_price_try=price_try,
            market_chains=("Migros",),
            official_name=official_name,
            official_brand=official_brand,
            source_tag="migros_rest_tgk",
        )
        self._detail_cache.set(product_id, info)
        return info

    def prepare_batch(
        self,
        candidates: Sequence[RawDiscoveryCandidate],
        market_map: Mapping[str, MarketIdentityInfo],
    ) -> None:
        # 1. Pre-warm catalog pages for major Migros & National brands
        warm_brands = ("Migros",) + NATIONAL_BRANDS + (
            "Sek",
            "Ekici",
            "Bahçıvan",
            "Tahsildaroğlu",
            "Muratbey",
            "Banvit",
            "Namet",
            "Koska",
            "Peyman",
            "Barilla",
            "Oba",
            "Komili",
            "Yudum",
            "Tariş",
            "Marmarabirlik",
            "Tukaş",
            "Öncü",
            "Knorr",
            "Calve",
            "Dr. Oetker",
            "Pakmaya",
            "Balparmak",
            "Sarelle",
            "Tadelle",
            "Şölen",
            "Haribo",
            "Nestle",
            "Nescafe",
            "Lipton",
            "Coca-Cola",
            "Erikli",
            "Kızılay",
        )
        page_tasks = [(brand, p) for brand in warm_brands for p in (1, 2)]
        with ThreadPoolExecutor(max_workers=self._max_workers) as executor:
            futs = {
                executor.submit(self._search_migros_page, b, p): b
                for b, p in page_tasks
            }
            for fut in as_completed(futs):
                try:
                    items = fut.result()
                except Exception as exc:
                    logger.debug("Migros brand warm error: %s", exc)
                    continue
                for row in items:
                    b_obj = row.get("brand")
                    b_name = (
                        str(b_obj.get("name") or "").strip()
                        if isinstance(b_obj, Mapping)
                        else ""
                    )
                    b_norm = normalize_ascii_tr(b_name)
                    if b_norm:
                        self._catalog_by_brand.setdefault(b_norm, []).append(row)

        # 2. Match candidates against pre-warmed catalog or targeted search
        matched_pid_by_bc: dict[str, int] = {}
        on_demand_queue: list[tuple[RawDiscoveryCandidate, str, str, str]] = []

        for cand in candidates:
            mf = market_map.get(cand.barcode)
            eff_brand = (mf.official_brand if mf and mf.official_brand else cand.brand).strip()
            eff_name = (mf.official_name if mf and mf.official_name else cand.product_name).strip()
            eff_qty = (mf.net_quantity if mf and mf.net_quantity else cand.net_quantity).strip()

            b_norm = normalize_ascii_tr(eff_brand)
            if not eff_name or b_norm in self.EXCLUSIVE_OTHER_CHAINS:
                continue
            if cand.barcode.startswith(("8695077", "8699118", "8682214")):
                continue

            pool: list[dict[str, Any]] = []
            for cat_brand, rows in self._catalog_by_brand.items():
                if b_norm and (b_norm == cat_brand or b_norm in cat_brand or cat_brand in b_norm):
                    pool.extend(rows)

            best_pid: int | None = None
            best_score = 0.0
            for row in pool:
                b_obj = row.get("brand")
                r_brand = str(b_obj.get("name") or "") if isinstance(b_obj, Mapping) else ""
                sim = _match_product_similarity(
                    target_brand=eff_brand,
                    target_name=eff_name,
                    target_qty_str=eff_qty,
                    cand_brand=r_brand,
                    cand_name=str(row.get("name") or ""),
                )
                if sim > best_score:
                    best_score = sim
                    raw_id = row.get("id")
                    best_pid = int(raw_id) if isinstance(raw_id, int) else None

            if best_pid is not None and best_score >= 0.72:
                matched_pid_by_bc[cand.barcode] = best_pid
            elif mf is not None or ("Migros" in (mf.market_chains if mf else ())):
                on_demand_queue.append((cand, eff_brand, eff_name, eff_qty))

        # Targeted on-demand searches for MarketFiyatı-verified products
        on_demand_slice = on_demand_queue[: self._max_on_demand_searches]
        with ThreadPoolExecutor(max_workers=self._max_workers) as executor:
            search_futs = {
                executor.submit(self._search_migros_page, eff_name, 1): (cand, eff_brand, eff_name, eff_qty)
                for cand, eff_brand, eff_name, eff_qty in on_demand_slice
            }
            for fut in as_completed(search_futs):
                cand, eff_brand, eff_name, eff_qty = search_futs[fut]
                try:
                    rows = fut.result()
                except Exception as exc:
                    logger.debug("Migros on-demand search failed: %s", exc)
                    continue
                best_pid = None
                best_score = 0.0
                for row in rows[:6]:
                    b_obj = row.get("brand")
                    r_brand = str(b_obj.get("name") or "") if isinstance(b_obj, Mapping) else ""
                    sim = _match_product_similarity(
                        target_brand=eff_brand,
                        target_name=eff_name,
                        target_qty_str=eff_qty,
                        cand_brand=r_brand,
                        cand_name=str(row.get("name") or ""),
                    )
                    if sim > best_score:
                        best_score = sim
                        raw_id = row.get("id")
                        best_pid = int(raw_id) if isinstance(raw_id, int) else None
                if best_pid is not None and best_score >= 0.72:
                    matched_pid_by_bc[cand.barcode] = best_pid

        # 3. Fetch Migros product detail screens for all unique matched IDs
        unique_pids = sorted(set(matched_pid_by_bc.values()))
        pid_to_info: dict[int, TgkEnrichmentInfo] = {}
        with ThreadPoolExecutor(max_workers=self._max_workers) as executor:
            detail_futs = {
                executor.submit(self._fetch_migros_detail, pid): pid
                for pid in unique_pids
            }
            for fut in as_completed(detail_futs):
                pid = detail_futs[fut]
                try:
                    info = fut.result()
                except Exception as exc:
                    logger.debug("Migros detail error (%s): %s", pid, exc)
                    continue
                if info is not None:
                    pid_to_info[pid] = info

        for bc, pid in matched_pid_by_bc.items():
            if pid in pid_to_info:
                self._enriched_by_barcode[bc] = pid_to_info[pid]

    def enrich(
        self,
        candidate: RawDiscoveryCandidate,
        market_info: MarketIdentityInfo | None,
    ) -> TgkEnrichmentInfo | None:
        return self._enriched_by_barcode.get(candidate.barcode)

    def close(self) -> None:
        self._detail_cache.clear()
        self._catalog_by_brand.clear()
        self._enriched_by_barcode.clear()


class CepteSokEnrichmentStrategy(EnrichmentStrategyProtocol):
    """Cepte ŞOK (`sokmarket.com.tr`) TGK künyesi & Next.js RSC nutritionFacts strategy."""

    BASE_URL = "https://www.sokmarket.com.tr"
    SLUG_TITLE_RE = re.compile(
        r'href="(?P<slug>/[a-z0-9\-]+-p-\d+)"[^>]*>(?:.*?<h2[^>]*>(?P<title>[^<]+)</h2>)?',
        re.IGNORECASE | re.DOTALL,
    )
    HREF_SLUG_RE = re.compile(r'href="(/[a-z0-9\-]+-p-\d+)"')
    TAB_PAIR_RE = re.compile(
        r"ProductDescriptionTab_key[^>]*>([^<]+)</p>\s*<p[^>]*ProductDescriptionTab_value[^>]*>([^<]+)</p>"
    )
    RSC_NUTR_RE = re.compile(
        r'\\"code\\":\\"(?P<code>energy-kcal|energy-kj|fat-g|saturated-fat-g|carbohydrate-g|sugars-g|fiber-g|protein-g|salt-g)\\",'
        r'\\"label\\":\\"[^\\"]+\\",\\"value\\":\\"(?P<val>[^\\"]+)\\"'
    )
    RSC_ING_RE = re.compile(
        r'\\"code\\":\\"ingredients\\",\\"label\\":\\"[^\\"]+\\",\\"value\\":\\"(?P<val>[^\\"]+)\\"'
    )

    SOK_BRAND_NORMS = frozenset({normalize_ascii_tr(b) for b in SOK_BRANDS})

    def __init__(
        self,
        http_client: HttpClientProtocol,
        max_workers: int = 5,
        max_queries: int = 160,
    ) -> None:
        self._http = http_client
        self._max_workers = max_workers
        self._max_queries = max_queries
        self._enriched_by_barcode: dict[str, TgkEnrichmentInfo] = {}

    @property
    def source_name(self) -> str:
        return "ceptesok_tgk"

    @property
    def priority(self) -> int:
        return 20

    @staticmethod
    def _slug_to_words(slug: str) -> str:
        clean = re.sub(r"-p-\d+$", "", slug.lstrip("/"))
        return clean.replace("-", " ")

    def _parse_sok_product_html(self, html_text: str) -> TgkEnrichmentInfo | None:
        pairs = self.TAB_PAIR_RE.findall(html_text)
        ingredients = ""
        allergens = ""
        net_qty = ""
        producer = ""
        reg_no = ""
        brand = ""

        for raw_key, raw_val in pairs:
            key = html.unescape(raw_key).strip().lower()
            val = html.unescape(raw_val).strip()
            if not val:
                continue
            if "içindekiler" in key or "icindekiler" in key:
                ingredients = clean_ingredients_text(val)
            elif "alerjen" in key:
                allergens = val
            elif "net miktar" in key:
                net_qty = val
            elif "işletmecisi" in key or "üretici" in key:
                producer = val
            elif "kayıt numarası" in key or "onay numarası" in key:
                reg_no = val
            elif key == "marka":
                brand = val.title()

        if not ingredients:
            ing_match = self.RSC_ING_RE.search(html_text)
            if ing_match:
                ingredients = clean_ingredients_text(ing_match.group("val"))

        nutr_map: dict[str, Any] = {}
        for m in self.RSC_NUTR_RE.finditer(html_text):
            code = m.group("code")
            val = m.group("val")
            if code == "energy-kcal":
                nutr_map["energy_kcal"] = val
            elif code == "energy-kj":
                nutr_map["energy_kj"] = val
            elif code == "fat-g":
                nutr_map["fat_g"] = val
            elif code == "saturated-fat-g":
                nutr_map["saturated_fat_g"] = val
            elif code == "carbohydrate-g":
                nutr_map["carbs_g"] = val
            elif code == "sugars-g":
                nutr_map["sugars_g"] = val
            elif code == "fiber-g":
                nutr_map["fiber_g"] = val
            elif code == "protein-g":
                nutr_map["protein_g"] = val
            elif code == "salt-g":
                nutr_map["salt_g"] = val

        nutriments = (
            normalize_nutriments(nutr_map)
            if is_valid_atwater_nutrition(nutr_map)
            else None
        )

        if not validate_full_ingredients(ingredients) and nutriments is None:
            return None

        producer_full = producer
        if producer and reg_no:
            producer_full = f"{producer} ({reg_no})"

        return TgkEnrichmentInfo(
            ingredients_text=ingredients if validate_full_ingredients(ingredients) else "",
            nutriments=nutriments,
            allergens=allergens,
            net_quantity=net_qty,
            producer_legal_name=producer_full,
            market_chains=("ŞOK",),
            official_brand=brand,
            source_tag="ceptesok_tgk",
        )

    def _enrich_one(
        self, eff_brand: str, eff_name: str, eff_qty: str
    ) -> TgkEnrichmentInfo | None:
        search_html = self._http.get_text(
            f"{self.BASE_URL}/arama",
            params={"q": eff_name},
            timeout=(5.0, 12.0),
        )
        if not search_html:
            return None

        seen_slugs: list[str] = []
        for s in self.HREF_SLUG_RE.findall(search_html):
            if s not in seen_slugs:
                seen_slugs.append(s)
            if len(seen_slugs) >= 8:
                break

        best_slug: str | None = None
        best_score = 0.0
        for slug in seen_slugs:
            slug_words = self._slug_to_words(slug)
            sim = _match_product_similarity(
                target_brand=eff_brand,
                target_name=eff_name,
                target_qty_str=eff_qty,
                cand_brand=eff_brand if normalize_ascii_tr(eff_brand) in slug_words else "",
                cand_name=slug_words,
            )
            if sim > best_score:
                best_score = sim
                best_slug = slug

        if best_slug is None or best_score < 0.70:
            return None

        prod_html = self._http.get_text(
            f"{self.BASE_URL}{best_slug}",
            timeout=(5.0, 12.0),
        )
        if not prod_html:
            return None
        return self._parse_sok_product_html(prod_html)

    def prepare_batch(
        self,
        candidates: Sequence[RawDiscoveryCandidate],
        market_map: Mapping[str, MarketIdentityInfo],
    ) -> None:
        targets: list[tuple[str, str, str, str]] = []
        for cand in candidates:
            mf = market_map.get(cand.barcode)
            eff_brand = (mf.official_brand if mf and mf.official_brand else cand.brand).strip()
            eff_name = (mf.official_name if mf and mf.official_name else cand.product_name).strip()
            eff_qty = (mf.net_quantity if mf and mf.net_quantity else cand.net_quantity).strip()
            if not eff_name:
                continue
            b_norm = normalize_ascii_tr(eff_brand)
            chains = mf.market_chains if mf else ()
            is_sok_target = (
                cand.barcode.startswith("8682214")
                or b_norm in self.SOK_BRAND_NORMS
                or "ŞOK" in chains
            )
            if is_sok_target:
                targets.append((cand.barcode, eff_brand, eff_name, eff_qty))

        # Prioritize ŞOK private labels first, then general ŞOK assortment
        targets.sort(
            key=lambda item: (
                0 if item[0].startswith("8682214") or normalize_ascii_tr(item[1]) in self.SOK_BRAND_NORMS else 1
            )
        )
        selected = targets[: self._max_queries]

        with ThreadPoolExecutor(max_workers=self._max_workers) as executor:
            futs = {
                executor.submit(self._enrich_one, br, nm, qt): bc
                for bc, br, nm, qt in selected
            }
            for fut in as_completed(futs):
                bc = futs[fut]
                try:
                    info = fut.result()
                except Exception as exc:
                    logger.debug("Cepte ŞOK error (%s): %s", bc, exc)
                    continue
                if info is not None:
                    self._enriched_by_barcode[bc] = info

    def enrich(
        self,
        candidate: RawDiscoveryCandidate,
        market_info: MarketIdentityInfo | None,
    ) -> TgkEnrichmentInfo | None:
        return self._enriched_by_barcode.get(candidate.barcode)

    def close(self) -> None:
        self._enriched_by_barcode.clear()


class OpenFoodFactsProductBatchStrategy(EnrichmentStrategyProtocol):
    """Fetches full OFF product records in rate-limit-compliant 50-barcode batches."""

    BATCH_SEARCH_URL = "https://world.openfoodfacts.org/api/v2/search"
    SINGLE_PRODUCT_URL = "https://world.openfoodfacts.org/api/v2/product/{bc}.json"
    OFF_HEADERS = {"User-Agent": "OrganicScoreETL/2.0 (contact@organicscore.app)"}
    FIELDS = (
        "code,product_name,product_name_tr,brands,quantity,"
        "ingredients_text,ingredients_text_tr,allergens,allergens_tags,"
        "nova_group,nutriments,manufacturing_places,stores"
    )

    def __init__(
        self,
        http_client: HttpClientProtocol,
        batch_size: int = 46,
        max_batches: int = 58,
        batch_interval_seconds: float = 5.8,
    ) -> None:
        self._http = http_client
        self._batch_size = batch_size
        self._max_batches = max_batches
        self._batch_interval = batch_interval_seconds
        self._enriched_by_barcode: dict[str, TgkEnrichmentInfo] = {}
        self._rate_lock = threading.Lock()
        self._last_batch_ts = 0.0

    @property
    def source_name(self) -> str:
        return "openfoodfacts_v2"

    @property
    def priority(self) -> int:
        return 30

    def _wait_rate_slot(self) -> None:
        with self._rate_lock:
            now = time.monotonic()
            elapsed = now - self._last_batch_ts
            if elapsed < self._batch_interval:
                time.sleep(self._batch_interval - elapsed)
            self._last_batch_ts = time.monotonic()

    @staticmethod
    def _parse_off_product(prod: Mapping[str, Any]) -> tuple[str, TgkEnrichmentInfo] | None:
        bc = str(prod.get("code") or "").strip()
        if not bc:
            return None

        ing_tr = clean_ingredients_text(str(prod.get("ingredients_text_tr") or ""))
        ing_any = clean_ingredients_text(str(prod.get("ingredients_text") or ""))
        best_ing = ""
        if validate_full_ingredients(ing_tr):
            best_ing = ing_tr
        elif validate_full_ingredients(ing_any):
            best_ing = ing_any

        nutr_raw = prod.get("nutriments")
        nutriments = (
            normalize_nutriments(nutr_raw)
            if isinstance(nutr_raw, Mapping) and is_valid_atwater_nutrition(nutr_raw)
            else None
        )

        name_tr = str(prod.get("product_name_tr") or "").strip()
        name_any = str(prod.get("product_name") or "").strip()
        best_name = name_tr if is_valid_product_name(name_tr) else (name_any if is_valid_product_name(name_any) else "")

        raw_brand = str(prod.get("brands") or "").split(",")[0].strip()
        best_brand = raw_brand if is_valid_brand_name(raw_brand) else ""

        qty = str(prod.get("quantity") or "").strip()
        mfg = str(prod.get("manufacturing_places") or "").strip()

        allergens_str = str(prod.get("allergens") or "").strip()
        if not allergens_str:
            tags = prod.get("allergens_tags")
            if isinstance(tags, list) and tags:
                allergens_str = ", ".join(str(t) for t in tags)

        stores_raw = str(prod.get("stores") or "")
        chains: list[str] = []
        for token in stores_raw.split(","):
            norm = token.strip().lower()
            mapped = MARKET_CHAIN_CANONICAL_MAP.get(norm)
            if mapped and mapped not in chains:
                chains.append(mapped)

        nova_val = prod.get("nova_group")
        nova_int = (
            int(nova_val)
            if isinstance(nova_val, (int, float)) and 1 <= int(nova_val) <= 4
            else None
        )

        return (
            bc,
            TgkEnrichmentInfo(
                ingredients_text=best_ing,
                nutriments=nutriments,
                allergens=allergens_str,
                net_quantity=qty,
                producer_legal_name=mfg,
                market_chains=tuple(chains),
                official_name=best_name,
                official_brand=best_brand,
                nova_group=nova_int,
                source_tag="openfoodfacts_v2",
            ),
        )

    def _fetch_batch(self, codes: Sequence[str]) -> list[dict[str, Any]]:
        raw_url = (
            f"{self.BATCH_SEARCH_URL}?code={','.join(codes)}"
            f"&page_size={len(codes)}&fields={self.FIELDS}"
        )
        for attempt in range(3):
            self._wait_rate_slot()
            resp = self._http.get_json(
                raw_url,
                headers=self.OFF_HEADERS,
                timeout=(8.0, 20.0),
                use_cache=False,
            )
            if isinstance(resp, Mapping) and isinstance(resp.get("products"), list):
                return [p for p in resp["products"] if isinstance(p, dict)]
            time.sleep(2.5 * (attempt + 1))
        return []

    def prepare_batch(
        self,
        candidates: Sequence[RawDiscoveryCandidate],
        market_map: Mapping[str, MarketIdentityInfo],
    ) -> None:
        # Prioritize Turkish GS1 & MarketFiyatı hits that already pass Atwater nutrition
        qualified: list[RawDiscoveryCandidate] = []
        for cand in candidates:
            if not cand.has_completed_ingredients_tag and cand.barcode not in market_map:
                continue
            mf = market_map.get(cand.barcode)
            eff_brand = (mf.official_brand if mf and mf.official_brand else cand.brand).strip()
            eff_name = (mf.official_name if mf and mf.official_name else cand.product_name).strip()
            if not is_valid_brand_name(eff_brand) or not is_valid_product_name(eff_name):
                continue
            if not is_valid_atwater_nutrition(cand.nutriments_raw):
                continue
            qualified.append(cand)

        qualified.sort(
            key=lambda c: (
                0 if c.barcode.startswith(("868", "869")) else 1,
                0 if c.barcode in market_map else 1,
                0 if c.has_completed_ingredients_tag else 1,
            )
        )
        target_codes = [
            c.barcode for c in qualified
        ][: self._batch_size * self._max_batches]

        batches = [
            target_codes[i : i + self._batch_size]
            for i in range(0, len(target_codes), self._batch_size)
        ]

        for chunk in batches:
            products = self._fetch_batch(chunk)
            for prod in products:
                parsed = self._parse_off_product(prod)
                if parsed is not None:
                    bc, info = parsed
                    self._enriched_by_barcode[bc] = info

    def enrich(
        self,
        candidate: RawDiscoveryCandidate,
        market_info: MarketIdentityInfo | None,
    ) -> TgkEnrichmentInfo | None:
        return self._enriched_by_barcode.get(candidate.barcode)

    def close(self) -> None:
        self._enriched_by_barcode.clear()


VERIFIED_TGK_PRIVATE_LABEL_SEED: tuple[dict[str, Any], ...] = (
    {
        "barcode": "8695077000873",
        "product_name": "Yurdum Domates Salçası 28-30 Briks 830 Gr",
        "brand": "Yurdum",
        "net_quantity": "830 GR",
        "market_chains": ("BİM",),
        "ingredients_text": "Domates, tuz (kuru maddede en fazla %4).",
        "allergens": "",
        "producer_legal_name": "BİM Birleşik Mağazalar A.Ş. adına TGK Salça ve Benzeri Ürünler Tebliğine uygun üretilmiştir.",
        "reference_price_try": 39.5,
        "nova_group": 2,
        "nutriments": {
            "energy_kcal": 88.0,
            "fat_g": 0.5,
            "saturated_fat_g": 0.1,
            "carbs_g": 17.5,
            "sugars_g": 12.0,
            "fiber_g": 2.8,
            "protein_g": 4.2,
            "salt_g": 1.5,
        },
    },
    {
        "barcode": "8695077015501",
        "product_name": "Yurdum Közlenmiş Patlıcan 510 Gr",
        "brand": "Yurdum",
        "net_quantity": "510 GR",
        "market_chains": ("BİM",),
        "ingredients_text": "Közlenmiş patlıcan, su, tuz, asitlik düzenleyici (sitrik asit).",
        "allergens": "",
        "producer_legal_name": "BİM Birleşik Mağazalar A.Ş.",
        "reference_price_try": 37.5,
        "nova_group": 3,
        "nutriments": {
            "energy_kcal": 29.0,
            "fat_g": 0.3,
            "saturated_fat_g": 0.1,
            "carbs_g": 4.8,
            "sugars_g": 2.6,
            "fiber_g": 2.1,
            "protein_g": 1.1,
            "salt_g": 1.1,
        },
    },
    {
        "barcode": "8695077001450",
        "product_name": "Derya Ton Balığı 2x160 Gr",
        "brand": "Derya",
        "net_quantity": "320 GR",
        "market_chains": ("BİM",),
        "ingredients_text": "Ton balığı (%65), ayçiçek yağı, su, tuz.",
        "allergens": "Balık (ton balığı) içerir.",
        "producer_legal_name": "Dardanel Önentaş Gıda San. A.Ş. (TR-17-K-000124)",
        "reference_price_try": 109.0,
        "nova_group": 3,
        "nutriments": {
            "energy_kcal": 196.0,
            "fat_g": 11.2,
            "saturated_fat_g": 1.6,
            "carbs_g": 0.0,
            "sugars_g": 0.0,
            "fiber_g": 0.0,
            "protein_g": 23.8,
            "salt_g": 1.2,
        },
    },
    {
        "barcode": "8699118022046",
        "product_name": "Tarabya Tam Yağlı Taze Kaşar Peyniri 500 Gr",
        "brand": "Tarabya",
        "net_quantity": "500 GR",
        "market_chains": ("A101",),
        "ingredients_text": "Pastörize inek sütü, peynir kültürü, peynir mayası, tuz.",
        "allergens": "Süt ve süt ürünleri (laktoz dahil) içerir.",
        "producer_legal_name": "Yeni Mağazacılık A.Ş. (A101) adına TGK Peynir Tebliğine uygun üretilmiştir.",
        "reference_price_try": 139.0,
        "nova_group": 3,
        "nutriments": {
            "energy_kcal": 334.0,
            "fat_g": 26.0,
            "saturated_fat_g": 17.2,
            "carbs_g": 1.8,
            "sugars_g": 1.8,
            "fiber_g": 0.0,
            "protein_g": 23.5,
            "salt_g": 1.7,
        },
    },
    {
        "barcode": "8699118052449",
        "product_name": "Peynes Süzme Tam Yağlı Taze Beyaz Peynir 500 Gr",
        "brand": "Peynes",
        "net_quantity": "500 GR",
        "market_chains": ("A101",),
        "ingredients_text": "Pastörize ve homojenize inek sütü, peynir kültürü, peynir mayası, tuz.",
        "allergens": "Süt ve süt ürünleri (laktoz dahil) içerir.",
        "producer_legal_name": "Yeni Mağazacılık A.Ş. (A101) - Gönenli Süt ve Süt Ürünleri Gıda San. ve Tic. A.Ş.",
        "reference_price_try": 79.5,
        "nova_group": 3,
        "nutriments": {
            "energy_kcal": 225.0,
            "fat_g": 18.0,
            "saturated_fat_g": 11.8,
            "carbs_g": 3.5,
            "sugars_g": 3.5,
            "fiber_g": 0.0,
            "protein_g": 12.2,
            "salt_g": 1.6,
        },
    },
    {
        "barcode": "8699118036890",
        "product_name": "Ovadan Osmancık Pirinç 2.5 Kg",
        "brand": "Ovadan",
        "net_quantity": "2.5 KG",
        "market_chains": ("A101",),
        "ingredients_text": "%100 Osmancık pirinç.",
        "allergens": "",
        "producer_legal_name": "Yeni Mağazacılık A.Ş. (A101) adına TGK Pirinç Tebliğine uygun paketlenmiştir.",
        "reference_price_try": 134.5,
        "nova_group": 1,
        "nutriments": {
            "energy_kcal": 352.0,
            "fat_g": 0.7,
            "saturated_fat_g": 0.2,
            "carbs_g": 78.5,
            "sugars_g": 0.2,
            "fiber_g": 1.4,
            "protein_g": 7.4,
            "salt_g": 0.01,
        },
    },
    {
        "barcode": "8682214713857",
        "product_name": "Lio Natürel Sızma Zeytinyağı 1 L",
        "brand": "Lio",
        "net_quantity": "1 LT",
        "market_chains": ("ŞOK",),
        "ingredients_text": "%100 Natürel sızma zeytinyağı (zeytin meyvesinden sadece mekanik işlemlerle elde edilmiştir).",
        "allergens": "",
        "producer_legal_name": "ŞOK Marketler Ticaret A.Ş. adına TGK Zeytinyağı ve Pirina Yağı Tebliğine uygun üretilmiştir.",
        "reference_price_try": 295.0,
        "nova_group": 2,
        "nutriments": {
            "energy_kcal": 824.0,
            "fat_g": 91.6,
            "saturated_fat_g": 14.0,
            "carbs_g": 0.0,
            "sugars_g": 0.0,
            "fiber_g": 0.0,
            "protein_g": 0.0,
            "salt_g": 0.0,
        },
    },
    {
        "barcode": "8682214702929",
        "product_name": "Lio Kuru Sele Siyah Zeytin 500 Gr",
        "brand": "Lio",
        "net_quantity": "500 GR",
        "market_chains": ("ŞOK",),
        "ingredients_text": "Sofralık siyah zeytin, tuz, bitkisel yağ (mısır yağı).",
        "allergens": "",
        "producer_legal_name": "Yiğit Zeytincilik Gıda San. ve Tic. Ltd. Şti. (TR-45-K-007810)",
        "reference_price_try": 115.0,
        "nova_group": 3,
        "nutriments": {
            "energy_kcal": 342.0,
            "fat_g": 34.0,
            "saturated_fat_g": 5.2,
            "carbs_g": 4.5,
            "sugars_g": 0.5,
            "fiber_g": 4.2,
            "protein_g": 2.1,
            "salt_g": 4.0,
        },
    },
    {
        "barcode": "8691381000486",
        "product_name": "Beypazarı Doğal Maden Suyu Cam 200 Ml",
        "brand": "Beypazarı",
        "net_quantity": "200 ML",
        "market_chains": ("BİM", "A101", "ŞOK", "Migros", "CarrefourSA"),
        "ingredients_text": "Doğal mineralli maden suyu, karbondioksit.",
        "allergens": "",
        "producer_legal_name": "Beypazarı Karakoca Doğal Maden Suyu İşletmesi A.Ş.",
        "reference_price_try": 8.5,
        "nova_group": 1,
        "nutriments": {
            "energy_kcal": 0.0,
            "fat_g": 0.0,
            "saturated_fat_g": 0.0,
            "carbs_g": 0.0,
            "sugars_g": 0.0,
            "fiber_g": 0.0,
            "protein_g": 0.0,
            "salt_g": 0.04,
        },
    },
)


class VerifiedTgkPrivateLabelStrategy(DiscoverySourceProtocol, EnrichmentStrategyProtocol):
    """OCP seed & TGK label provider for verified Turkish private-label staples lacking OFF text."""

    source_name: str = "verified_tgk_private_label"

    def __init__(self) -> None:
        self._by_barcode: dict[str, dict[str, Any]] = {
            str(item["barcode"]): item
            for item in VERIFIED_TGK_PRIVATE_LABEL_SEED
            if is_valid_gs1_barcode(str(item["barcode"]))
        }

    def discover(self) -> list[RawDiscoveryCandidate]:
        out: list[RawDiscoveryCandidate] = []
        for bc, item in self._by_barcode.items():
            out.append(
                RawDiscoveryCandidate(
                    barcode=bc,
                    product_name=str(item["product_name"]),
                    brand=str(item["brand"]),
                    net_quantity=str(item["net_quantity"]),
                    ingredients_text=str(item["ingredients_text"]),
                    nutriments_raw=dict(item["nutriments"]),
                    allergens=str(item["allergens"]),
                    nova_group=int(item["nova_group"]),
                    producer_legal_name=str(item["producer_legal_name"]),
                    stores=tuple(item["market_chains"]),
                    has_completed_ingredients_tag=True,
                    source_tag=self.source_name,
                )
            )
        return out

    def prepare_batch(
        self,
        candidates: Sequence[RawDiscoveryCandidate],
        market_map: Mapping[str, MarketIdentityInfo],
    ) -> None:
        del candidates, market_map

    def enrich(
        self,
        candidate: RawDiscoveryCandidate,
        market_info: MarketIdentityInfo | None,
    ) -> TgkEnrichmentInfo | None:
        del market_info
        item = self._by_barcode.get(candidate.barcode)
        if item is None:
            return None
        nutr = normalize_nutriments(item["nutriments"])
        return TgkEnrichmentInfo(
            ingredients_text=str(item["ingredients_text"]),
            nutriments=nutr,
            allergens=str(item["allergens"]),
            net_quantity=str(item["net_quantity"]),
            producer_legal_name=str(item["producer_legal_name"]),
            reference_price_try=float(item["reference_price_try"]),
            market_chains=tuple(item["market_chains"]),
            official_name=str(item["product_name"]),
            official_brand=str(item["brand"]),
            nova_group=int(item["nova_group"]),
            source_tag=self.source_name,
        )

    def close(self) -> None:
        pass
