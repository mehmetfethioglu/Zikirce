"""Domain contracts, DTOs, DIP protocols, bounded cache, and OCP SourceRegistry.

Strict leaf module in the DAG (zero internal package imports).
"""

from __future__ import annotations

import threading
import time
from collections import OrderedDict
from dataclasses import dataclass, field
from typing import (
    Any,
    Generic,
    Mapping,
    Protocol,
    Sequence,
    TypeVar,
    runtime_checkable,
)

K = TypeVar("K")
V = TypeVar("V")


class BoundedTtlLruCache(Generic[K, V]):
    """Thread-safe bounded LRU cache with monotonic TTL expiration."""

    def __init__(self, maxsize: int = 2048, ttl_seconds: float = 3600.0) -> None:
        if maxsize <= 0:
            raise ValueError("maxsize must be positive")
        if ttl_seconds <= 0:
            raise ValueError("ttl_seconds must be positive")
        self._maxsize = maxsize
        self._ttl = ttl_seconds
        self._store: OrderedDict[K, tuple[float, V]] = OrderedDict()
        self._lock = threading.Lock()

    def get(self, key: K) -> tuple[bool, V | None]:
        now = time.monotonic()
        with self._lock:
            entry = self._store.get(key)
            if entry is None:
                return False, None
            expires_at, value = entry
            if now >= expires_at:
                del self._store[key]
                return False, None
            self._store.move_to_end(key)
            return True, value

    def set(self, key: K, value: V) -> None:
        expires_at = time.monotonic() + self._ttl
        with self._lock:
            if key in self._store:
                self._store.move_to_end(key)
            self._store[key] = (expires_at, value)
            while len(self._store) > self._maxsize:
                self._store.popitem(last=False)

    def clear(self) -> None:
        with self._lock:
            self._store.clear()


@dataclass(frozen=True, slots=True)
class Nutriments100g:
    """Validated 100g nutritional profile adhering to Atwater constraints."""

    energy_kcal: float
    fat_g: float
    saturated_fat_g: float
    carbs_g: float
    sugars_g: float
    fiber_g: float
    protein_g: float
    salt_g: float

    def to_dict(self) -> dict[str, float]:
        return {
            "energy_kcal": round(self.energy_kcal, 2),
            "fat_g": round(self.fat_g, 2),
            "saturated_fat_g": round(self.saturated_fat_g, 2),
            "carbs_g": round(self.carbs_g, 2),
            "sugars_g": round(self.sugars_g, 2),
            "fiber_g": round(self.fiber_g, 2),
            "protein_g": round(self.protein_g, 2),
            "salt_g": round(self.salt_g, 2),
        }


@dataclass(frozen=True, slots=True)
class AlternativeSuggestion:
    """Clean-label alternative product recommendation."""

    name: str
    brand: str
    reason: str

    def to_dict(self) -> dict[str, str]:
        return {
            "name": self.name,
            "brand": self.brand,
            "reason": self.reason,
        }


@dataclass(frozen=True, slots=True)
class AiSummaryPayload:
    """Complete biochemical & TGK summary payload stored per market product."""

    organic_score: int
    nova_group: int
    verdict: str
    summary: str
    warnings: tuple[str, ...]
    alternatives: tuple[AlternativeSuggestion, ...]
    ingredients_text: str
    nutriments: Nutriments100g
    allergens: str
    market_chains: tuple[str, ...]
    net_quantity: str
    producer_legal_name: str
    reference_price_try: float | None
    data_source: str

    def to_dict(self) -> dict[str, Any]:
        return {
            "organic_score": int(self.organic_score),
            "nova_group": int(self.nova_group),
            "verdict": self.verdict,
            "summary": self.summary,
            "warnings": list(self.warnings),
            "alternatives": [alt.to_dict() for alt in self.alternatives],
            "ingredients_text": self.ingredients_text,
            "nutriments": self.nutriments.to_dict(),
            "allergens": self.allergens,
            "market_chains": list(self.market_chains),
            "net_quantity": self.net_quantity,
            "producer_legal_name": self.producer_legal_name,
            "reference_price_try": (
                round(self.reference_price_try, 2)
                if self.reference_price_try is not None
                else None
            ),
            "data_source": self.data_source,
        }


@dataclass(frozen=True, slots=True)
class MarketProductRecord:
    """Canonical top-level product snapshot contract for JSON and SQLite."""

    barcode: str
    product_name: str
    brand: str
    ai_summary_json: AiSummaryPayload

    def to_dict(self) -> dict[str, Any]:
        return {
            "barcode": self.barcode,
            "product_name": self.product_name,
            "brand": self.brand,
            "ai_summary_json": self.ai_summary_json.to_dict(),
        }


@dataclass(slots=True)
class RawDiscoveryCandidate:
    """Intermediate barcode discovery candidate prior to verification/enrichment."""

    barcode: str
    product_name: str = ""
    brand: str = ""
    net_quantity: str = ""
    ingredients_text: str = ""
    nutriments_raw: dict[str, Any] = field(default_factory=dict)
    allergens: str = ""
    nova_group: int | None = None
    producer_legal_name: str = ""
    stores: tuple[str, ...] = ()
    has_completed_ingredients_tag: bool = False
    source_tag: str = "openfoodfacts_search"


@dataclass(frozen=True, slots=True)
class MarketIdentityInfo:
    """Official market verification result (e.g. TÜBİTAK MarketFiyatı)."""

    barcode: str
    official_name: str
    official_brand: str
    net_quantity: str
    reference_price_try: float | None
    market_chains: tuple[str, ...]
    source_tag: str = "tubitak_marketfiyati"


@dataclass(frozen=True, slots=True)
class TgkEnrichmentInfo:
    """TGK food label enrichment payload from retail/catalog strategies."""

    ingredients_text: str = ""
    nutriments: Nutriments100g | None = None
    allergens: str = ""
    net_quantity: str = ""
    producer_legal_name: str = ""
    reference_price_try: float | None = None
    market_chains: tuple[str, ...] = ()
    official_name: str = ""
    official_brand: str = ""
    nova_group: int | None = None
    source_tag: str = ""


@runtime_checkable
class HttpClientProtocol(Protocol):
    """DIP abstraction over pooled HTTP transport with explicit timeouts."""

    def get_json(
        self,
        url: str,
        *,
        params: Mapping[str, Any] | None = None,
        headers: Mapping[str, str] | None = None,
        timeout: tuple[float, float] = (5.0, 12.0),
        use_cache: bool = True,
    ) -> Any | None: ...

    def post_json(
        self,
        url: str,
        *,
        payload: Mapping[str, Any],
        headers: Mapping[str, str] | None = None,
        timeout: tuple[float, float] = (5.0, 12.0),
    ) -> Any | None: ...

    def get_text(
        self,
        url: str,
        *,
        params: Mapping[str, Any] | None = None,
        headers: Mapping[str, str] | None = None,
        timeout: tuple[float, float] = (5.0, 12.0),
        use_cache: bool = True,
    ) -> str | None: ...

    def close(self) -> None: ...


@runtime_checkable
class DiscoverySourceProtocol(Protocol):
    """Strategy contract for discovering real GS1 barcode candidates."""

    @property
    def source_name(self) -> str: ...

    def discover(self) -> list[RawDiscoveryCandidate]: ...

    def close(self) -> None: ...


@runtime_checkable
class MarketVerifierProtocol(Protocol):
    """Strategy contract for verifying official market chain & price metadata."""

    @property
    def source_name(self) -> str: ...

    def verify_candidates(
        self, candidates: Sequence[RawDiscoveryCandidate]
    ) -> dict[str, MarketIdentityInfo]: ...

    def close(self) -> None: ...


@runtime_checkable
class EnrichmentStrategyProtocol(Protocol):
    """Strategy contract for enriching TGK ingredients, nutrition, and legal producer."""

    @property
    def source_name(self) -> str: ...

    @property
    def priority(self) -> int: ...

    def prepare_batch(
        self,
        candidates: Sequence[RawDiscoveryCandidate],
        market_map: Mapping[str, MarketIdentityInfo],
    ) -> None: ...

    def enrich(
        self,
        candidate: RawDiscoveryCandidate,
        market_info: MarketIdentityInfo | None,
    ) -> TgkEnrichmentInfo | None: ...

    def close(self) -> None: ...


class SourceRegistry:
    """Open/Closed Strategy Registry managing discovery, verification, and enrichment."""

    def __init__(self) -> None:
        self._discovery_sources: list[DiscoverySourceProtocol] = []
        self._market_verifiers: list[MarketVerifierProtocol] = []
        self._enrichment_strategies: list[EnrichmentStrategyProtocol] = []

    def register_discovery(self, source: DiscoverySourceProtocol) -> None:
        self._discovery_sources.append(source)

    def register_verifier(self, verifier: MarketVerifierProtocol) -> None:
        self._market_verifiers.append(verifier)

    def register_enrichment(self, strategy: EnrichmentStrategyProtocol) -> None:
        self._enrichment_strategies.append(strategy)
        self._enrichment_strategies.sort(key=lambda item: item.priority)

    @property
    def discovery_sources(self) -> tuple[DiscoverySourceProtocol, ...]:
        return tuple(self._discovery_sources)

    @property
    def market_verifiers(self) -> tuple[MarketVerifierProtocol, ...]:
        return tuple(self._market_verifiers)

    @property
    def enrichment_strategies(self) -> tuple[EnrichmentStrategyProtocol, ...]:
        return tuple(self._enrichment_strategies)

    def close_all(self) -> None:
        for src in self._discovery_sources:
            src.close()
        for ver in self._market_verifiers:
            ver.close()
        for strat in self._enrichment_strategies:
            strat.close()
