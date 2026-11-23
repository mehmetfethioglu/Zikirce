"""Kilerce Market ETL orchestrator, biochemical analyzer, and atomic SQLite/JSON repository.

Follows SRP, OCP (SourceRegistry), DIP (Protocol injection), and Jidoka quality gates.
"""

from __future__ import annotations

import json
import logging
import os
import re
import sqlite3
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Any, Mapping, Sequence

from .contracts import (
    AiSummaryPayload,
    AlternativeSuggestion,
    MarketIdentityInfo,
    MarketProductRecord,
    Nutriments100g,
    RawDiscoveryCandidate,
    SourceRegistry,
    TgkEnrichmentInfo,
)
from .sources import (
    A101_BRANDS,
    BIM_BRANDS,
    MARKET_CHAIN_CANONICAL_MAP,
    SOK_BRANDS,
    CepteSokEnrichmentStrategy,
    MarketFiyatiVerifierSource,
    MigrosRestEnrichmentStrategy,
    OpenFoodFactsProductBatchStrategy,
    OpenFoodFactsSearchSource,
    PooledHttpClient,
    VerifiedTgkPrivateLabelStrategy,
)
from .validators import (
    clean_ingredients_text,
    is_valid_atwater_nutrition,
    is_valid_brand_name,
    is_valid_gs1_barcode,
    is_valid_product_name,
    normalize_ascii_tr,
    normalize_nutriments,
    validate_full_ingredients,
)

logger = logging.getLogger(__name__)

# Biochemical marker registry (Turkish + English packaging terms)
ULTRA_PROCESSED_TERMS: dict[str, tuple[str, int]] = {
    "glikoz şurubu": ("Glikoz Şurubu (Yüksek Früktoz)", 15),
    "glikoz-fruktoz şurubu": ("Glikoz-Fruktoz Şurubu", 15),
    "fruktoz şurubu": ("Fruktoz Şurubu", 15),
    "glucose syrup": ("Glikoz Şurubu", 15),
    "glucose-fructose syrup": ("Glikoz-Fruktoz Şurubu", 15),
    "invert şeker şurubu": ("İnvert Şeker Şurubu", 12),
    "palm yağı": ("Palm Yağı", 15),
    "palm çekirdeği yağı": ("Palm Çekirdeği Yağı", 15),
    "hurma yağı": ("Palm / Hurma Yağı", 15),
    "palm oil": ("Palm Yağı", 15),
    "hidrojenize": ("Hidrojenize Bitkisel Yağ (Trans Yağ Riski)", 20),
    "hydrogenated": ("Hidrojenize Bitkisel Yağ (Trans Yağ Riski)", 20),
    "monosodyum glutamat": ("Monosodyum Glutamat (E621 / Lezzet Artırıcı)", 20),
    "monosodium glutamate": ("Monosodyum Glutamat (E621)", 20),
    "e621": ("E621 (Monosodyum Glutamat)", 20),
    "sodyum nitrit": ("E250 (Sodyum Nitrit / Koruyucu)", 25),
    "e250": ("E250 (Sodyum Nitrit / Koruyucu)", 25),
    "e251": ("E251 (Sodyum Nitrat / Koruyucu)", 20),
    "e252": ("E252 (Potasyum Nitrat / Koruyucu)", 20),
    "e951": ("E951 (Aspartam / Yapay Tatlandırıcı)", 20),
    "aspartam": ("Aspartam (Yapay Tatlandırıcı)", 20),
    "asesülfam": ("Asesülfam K (Yapay Tatlandırıcı)", 15),
    "acesulfame": ("Asesülfam K (Yapay Tatlandırıcı)", 15),
    "sukraloz": ("Sukraloz (Yapay Tatlandırıcı)", 15),
    "sucralose": ("Sukraloz (Yapay Tatlandırıcı)", 15),
    "sakkarin": ("Sakkarin (Yapay Tatlandırıcı)", 15),
    "titanyum dioksit": ("E171 (Titanyum Dioksit / Renklendirici)", 30),
    "e171": ("E171 (Titanyum Dioksit)", 30),
    "e102": ("E102 (Tartrazin / Sentetik Renklendirici)", 15),
    "tartrazin": ("Tartrazin (Sentetik Renklendirici)", 15),
    "e129": ("E129 (Allura Red / Sentetik Renklendirici)", 15),
    "e133": ("E133 (Brilliant Blue / Sentetik Renklendirici)", 15),
    "emülgatör": ("Emülgatör (İşlenmiş Katkı Maddesi)", 8),
    "emulsifier": ("Emülgatör (İşlenmiş Katkı Maddesi)", 8),
    "soya lesitini": ("Soya Lesitini (Emülgatör)", 5),
    "soy lecithin": ("Soya Lesitini (Emülgatör)", 5),
    "soja-lecithin": ("Soya Lesitini (Emülgatör)", 5),
    "koruyucu": ("Kimyasal Koruyucu Madde", 10),
    "potasyum sorbat": ("Potasyum Sorbat (E202 / Koruyucu)", 10),
    "sodyum benzoat": ("Sodyum Benzoat (E211 / Koruyucu)", 12),
    "aroma verici": ("Aroma Verici", 8),
    "flavouring": ("Aroma Verici", 8),
    "aroma": ("Aroma Verici", 6),
    "asitlik düzenleyici": ("Asitlik Düzenleyici", 5),
    "kıvam artırıcı": ("Kıvam Artırıcı / Stabilizatör", 6),
    "kıvam arttırıcı": ("Kıvam Artırıcı / Stabilizatör", 6),
    "maltodekstrin": ("Maltodekstrin (Yüksek Glisemik İndeks)", 12),
    "maltodextrin": ("Maltodekstrin (Yüksek Glisemik İndeks)", 12),
    "karagenan": ("E407 (Karagenan / Kıvam Artırıcı)", 18),
    "karragenan": ("E407 (Karagenan / Kıvam Artırıcı)", 18),
    "carrageenan": ("E407 (Karagenan / Kıvam Artırıcı)", 18),
    "e407": ("E407 (Karagenan)", 18),
}

NATURAL_FOOD_TERMS: tuple[str, ...] = (
    "süt",
    "yoğurt",
    "peynir",
    "lor",
    "tereyağı",
    "zeytinyağı",
    "yulaf",
    "pirinç",
    "mercimek",
    "nohut",
    "fasulye",
    "bulgur",
    "un",
    "irmik",
    "maden suyu",
    "fındık",
    "ceviz",
    "badem",
    "bal",
    "yumurta",
    "zeytin",
    "salça",
    "domates",
    "çay",
    "su",
)

ALLERGEN_TAG_TR_MAP: dict[str, str] = {
    "milk": "Süt ve süt ürünleri (laktoz)",
    "gluten": "Gluten (tahıllar)",
    "soybeans": "Soya",
    "soya": "Soya",
    "nuts": "Sert kabuklu yemişler (fındık/badem/ceviz/fıstık)",
    "peanuts": "Yer fıstığı",
    "eggs": "Yumurta",
    "sesame-seeds": "Susam",
    "sesame": "Susam",
    "mustard": "Hardal",
    "celery": "Kereviz",
    "fish": "Balık",
    "crustaceans": "Kabuklu deniz ürünleri",
    "molluscs": "Yumuşakçalar",
    "lupin": "Acı bakla",
    "sulphur-dioxide-and-sulphites": "Kükürt dioksit ve sülfitler",
}

INGREDIENT_ALLERGEN_PATTERNS: tuple[tuple[re.Pattern[str], str], ...] = (
    (
        re.compile(
            r"\b(süt|süttozu|süt tozu|peynir|yoğurt|tereyağ|krema|laktoz|peyniraltı|whey|milk|lactose|butter|cheese)\b",
            re.IGNORECASE,
        ),
        "Süt ve süt ürünleri (laktoz)",
    ),
    (
        re.compile(
            r"\b(buğday|gluten|arpa|çavdar|yulaf|irmik|wheat|barley|rye|oat)\b",
            re.IGNORECASE,
        ),
        "Gluten",
    ),
    (
        re.compile(r"\b(soya|soy|soja)\b", re.IGNORECASE),
        "Soya",
    ),
    (
        re.compile(
            r"\b(fındık|badem|ceviz|antep fıstığı|kaju|hazelnut|almond|walnut|pistachio|cashew)\b",
            re.IGNORECASE,
        ),
        "Sert kabuklu yemişler",
    ),
    (
        re.compile(r"\b(yer fıstığı|yerfıstığı|peanut)\b", re.IGNORECASE),
        "Yer fıstığı",
    ),
    (
        re.compile(r"\b(yumurta|egg|ei)\b", re.IGNORECASE),
        "Yumurta",
    ),
    (
        re.compile(r"\b(susam|tahin|sesame)\b", re.IGNORECASE),
        "Susam",
    ),
    (
        re.compile(r"\b(hardal|mustard)\b", re.IGNORECASE),
        "Hardal",
    ),
    (
        re.compile(r"\b(kereviz|celery)\b", re.IGNORECASE),
        "Kereviz",
    ),
    (
        re.compile(r"\b(balık|ton balığı|somon|hamsi|tuna|fish)\b", re.IGNORECASE),
        "Balık",
    ),
    (
        re.compile(r"\b(sülfit|metabisülfit|kükürt dioksit|sulphite|sulfite)\b", re.IGNORECASE),
        "Kükürt dioksit ve sülfitler",
    ),
)

BRAND_LEGAL_ENTITY_MAP: dict[str, str] = {
    "ulker": "Ülker Bisküvi Sanayi A.Ş.",
    "eti": "Eti Gıda Sanayi ve Ticaret A.Ş.",
    "torku": "Konya Şeker Sanayi ve Ticaret A.Ş.",
    "sutas": "Sütaş Süt Ürünleri A.Ş.",
    "pinar": "Pınar Süt Mamulleri Sanayii A.Ş.",
    "beypazari": "Beypazarı Karakoca Doğal Maden Suyu A.Ş.",
    "dimes": "Dimes Gıda Sanayi ve Ticaret A.Ş.",
    "zuber": "Alternatif Gıda Sanayi ve Ticaret A.Ş. (Züber)",
    "caykur": "Çay İşletmeleri Genel Müdürlüğü (ÇAYKUR)",
    "icim": "Ak Gıda Sanayi ve Ticaret A.Ş.",
    "tat": "Tat Gıda Sanayi A.Ş.",
    "duru": "Duru Bulgur Gıda Sanayi ve Ticaret A.Ş.",
    "yayla": "Yayla Agro Gıda Sanayi ve Nakliyat A.Ş.",
    "filiz": "Barilla Gıda A.Ş. (Filiz)",
    "barilla": "Barilla Gıda A.Ş.",
    "tadim": "Tadım Gıda Maddeleri Sanayi ve Ticaret A.Ş.",
    "uludag": "Uludağ İçecek Türk A.Ş.",
    "doganay": "Doğanay Gıda Tarım ve Hayvancılık San. Tic. A.Ş.",
    "dost": "BİM Birleşik Mağazalar A.Ş. (Dost)",
    "aknaz": "BİM Birleşik Mağazalar A.Ş. (Aknaz)",
    "efsane": "BİM Birleşik Mağazalar A.Ş. (Efsane)",
    "saban": "BİM Birleşik Mağazalar A.Ş. (Saban)",
    "sole": "BİM Birleşik Mağazalar A.Ş. (Sole)",
    "yurdum": "BİM Birleşik Mağazalar A.Ş. (Yurdum)",
    "simbat": "BİM Birleşik Mağazalar A.Ş. (Simbat)",
    "peripella": "BİM Birleşik Mağazalar A.Ş. (Peripella)",
    "derya": "BİM Birleşik Mağazalar A.Ş. (Derya)",
    "birsah": "Yeni Mağazacılık A.Ş. - A101 (Birşah)",
    "tarabya": "Yeni Mağazacılık A.Ş. - A101 (Tarabya)",
    "peynes": "Yeni Mağazacılık A.Ş. - A101 (Peynes)",
    "ahir": "Yeni Mağazacılık A.Ş. - A101 (Ahir)",
    "vera": "Yeni Mağazacılık A.Ş. - A101 (Vera)",
    "ovadan": "Yeni Mağazacılık A.Ş. - A101 (Ovadan)",
    "cokca": "Yeni Mağazacılık A.Ş. - A101 (Çokça)",
    "bendo": "Yeni Mağazacılık A.Ş. - A101 (Bendo)",
    "mis": "Şok Marketler Ticaret A.Ş. (Mis)",
    "piyale": "Şok Marketler Ticaret A.Ş. (Piyale)",
    "lio": "Şok Marketler Ticaret A.Ş. (Lio)",
    "evin": "Şok Marketler Ticaret A.Ş. (Evin)",
    "amigo": "Şok Marketler Ticaret A.Ş. (Amigo)",
    "karmen": "Şok Marketler Ticaret A.Ş. (Karmen)",
    "migros": "Migros Ticaret A.Ş.",
    "carrefour": "CarrefourSA Carrefour Sabancı Ticaret Merkezi A.Ş.",
    "carrefoursa": "CarrefourSA Carrefour Sabancı Ticaret Merkezi A.Ş.",
    "tarim kredi": "Tarım Kredi Pazarlama ve Marketçilik A.Ş.",
    "sek": "Tat Gıda / Sek Süt İşletmeleri A.Ş.",
    "ekici": "Ekiciler Süt Gıda Tarım Hayvancılık San. ve Tic. A.Ş.",
    "bahcivan": "Bahçıvan Gıda Sanayi ve Ticaret A.Ş.",
    "koska": "Merter Helva Sanayi ve Ticaret A.Ş. (Koska)",
    "haribo": "Haribo Şekerleme Sanayi ve Ticaret Ltd. Şti.",
    "coca cola": "Coca-Cola İçecek A.Ş.",
    "nestle": "Nestlé Türkiye Gıda Sanayi A.Ş.",
    "knorr": "Unilever Sanayi ve Ticaret Türk A.Ş.",
    "lipton": "Lipton Çay Üretim A.Ş.",
    "algida": "Unilever Sanayi ve Ticaret Türk A.Ş. (Algida)",
    "dr oetker": "Dr. Oetker Gıda Sanayi ve Ticaret A.Ş.",
    "danone": "Danone Tikveşli Gıda ve İçecek San. ve Tic. A.Ş.",
    "activia": "Danone Tikveşli Gıda ve İçecek San. ve Tic. A.Ş.",
    "milka": "Mondelēz International Türkiye Gıda A.Ş.",
    "ferrero": "Ferrero Türkiye Çikolata ve Tarım Ürünleri San. ve Dış Tic. A.Ş.",
    "kinder": "Ferrero Türkiye Çikolata ve Tarım Ürünleri San. ve Dış Tic. A.Ş.",
    "nutella": "Ferrero Türkiye Çikolata ve Tarım Ürünleri San. ve Dış Tic. A.Ş.",
    "komili": "Bunge Gıda Sanayi ve Ticaret A.Ş. (Komili)",
    "yudum": "Savola Gıda Sanayi ve Ticaret A.Ş. (Yudum)",
    "taris": "Tariş Zeytin ve Zeytinyağı Tarım Satış Kooperatifleri Birliği",
}

PRIVATE_LABEL_CHAIN_BY_BRAND: dict[str, str] = {
    **{normalize_ascii_tr(b): "BİM" for b in BIM_BRANDS},
    **{normalize_ascii_tr(b): "A101" for b in A101_BRANDS},
    **{normalize_ascii_tr(b): "ŞOK" for b in SOK_BRANDS},
    "migros": "Migros",
    "carrefour": "CarrefourSA",
    "carrefoursa": "CarrefourSA",
    "tarim kredi": "Tarım Kredi",
}

_E_NUMBER_RE = re.compile(r"\b[Ee][\s\-\.]?(\d{3,4}[a-z]?)\b")
_QTY_EXTRACT_RE = re.compile(
    r"\b(\d+(?:[.,]\d+)?\s*(?:kg|gr|g|mg|lt|l|ml|cl))\b", re.IGNORECASE
)


class BiochemicalAnalyzer:
    """Deterministic NOVA 1..4 & OrganicScore (0..100) analyzer with zero truncation."""

    @staticmethod
    def analyze(
        *,
        name: str,
        brand: str,
        ingredients_text: str,
        nutriments: Nutriments100g,
        raw_nova: int | None = None,
    ) -> tuple[int, int, str, str, tuple[str, ...], tuple[AlternativeSuggestion, ...]]:
        ing_lower = ingredients_text.lower()
        name_lower = name.lower()

        found_warnings: list[str] = []
        total_penalty = 0
        detected_keys: set[str] = set()

        for key, (label, penalty) in ULTRA_PROCESSED_TERMS.items():
            if key in ing_lower:
                detected_keys.add(key)
                msg = f"İçeriğinde '{label}' bulundu."
                if msg not in found_warnings:
                    found_warnings.append(msg)
                total_penalty += penalty

        e_numbers = _E_NUMBER_RE.findall(ingredients_text)
        for enum in e_numbers:
            full_code = f"E{enum.upper()}"
            if not any(full_code in w for w in found_warnings):
                found_warnings.append(f"Katkı maddesi: {full_code}")
                total_penalty += 6

        if nutriments.sugars_g > 15.0:
            found_warnings.append(
                f"Yüksek Şeker Oranı (100g üründe {nutriments.sugars_g:.1f}g şeker)."
            )
            total_penalty += 15
        elif nutriments.sugars_g > 8.0:
            total_penalty += 8

        if nutriments.saturated_fat_g > 5.0:
            found_warnings.append(
                f"Yüksek Doymuş Yağ ({nutriments.saturated_fat_g:.1f}g / 100g)."
            )
            total_penalty += 12
        elif nutriments.saturated_fat_g > 2.5:
            total_penalty += 6

        if nutriments.salt_g > 1.5:
            found_warnings.append(
                f"Yüksek Tuz İçeriği ({nutriments.salt_g:.2f}g / 100g)."
            )
            total_penalty += 12

        is_ultra = (
            len(detected_keys) >= 2
            or "palm" in ing_lower
            or "glikoz" in ing_lower
            or "glucose" in ing_lower
            or "fruktoz" in ing_lower
            or "hidrojenize" in ing_lower
            or "hydrogenated" in ing_lower
            or "e621" in ing_lower
            or "aspartam" in ing_lower
            or raw_nova == 4
        )

        is_pure_natural = (
            not is_ultra
            and len(detected_keys) == 0
            and len(e_numbers) == 0
            and (
                any(t in name_lower for t in NATURAL_FOOD_TERMS)
                or len(ingredients_text.split(",")) <= 2
                or raw_nova == 1
            )
        )

        if is_ultra:
            nova = 4
            verdict = "Aşırı İşlenmiş Gıda (NOVA 4)"
            base_score = 45
        elif is_pure_natural:
            nova = 1
            verdict = "İşlenmemiş / Doğal Gıda (NOVA 1)"
            base_score = 95
        elif (
            any(t in name_lower for t in ("un", "yağ", "zeytinyağı", "sirke", "tuz", "şeker"))
            and len(found_warnings) == 0
        ):
            nova = 2
            verdict = "İşlenmiş Mutfak Malzemesi (NOVA 2)"
            base_score = 85
        else:
            nova = 3
            verdict = "İşlenmiş Gıda (NOVA 3)"
            base_score = 70

        final_score = base_score - (total_penalty // 2)
        if nova == 1:
            final_score = max(80, min(100, final_score))
        elif nova == 4:
            final_score = max(10, min(48, final_score))
        else:
            final_score = max(35, min(82, final_score))

        alternatives = BiochemicalAnalyzer._build_alternatives(
            name_lower=name_lower, brand=brand, nova=nova, score=final_score
        )

        # Full untruncated summary (never uses [:160] or ...)
        summary = (
            f"{brand} markasına ait {name} ({verdict}, Skor: {final_score}/100). "
            f"İçindekiler: {ingredients_text}"
        )

        return (
            final_score,
            nova,
            verdict,
            summary,
            tuple(found_warnings),
            alternatives,
        )

    @staticmethod
    def _build_alternatives(
        *, name_lower: str, brand: str, nova: int, score: int
    ) -> tuple[AlternativeSuggestion, ...]:
        if nova == 4 or score < 60:
            if any(w in name_lower for w in ("çikolata", "gofret", "bisküvi", "bar", "kek", "chocolate", "wafer")):
                return (
                    AlternativeSuggestion(
                        name="Züber Fındıklı Kakaolu Meyve Barı",
                        brand="Züber",
                        reason="İlave rafine şekersiz, katkısız meyve ve kuruyemiş içeriği",
                    ),
                    AlternativeSuggestion(
                        name="Eti Lifalif Yulaf Ezmesi",
                        brand="Eti",
                        reason="Tam tahıl lif kaynağı, koruyucu ve palm yağı içermez",
                    ),
                )
            if any(w in name_lower for w in ("cips", "kraker", "atıştırmalık", "chips", "cracker")):
                return (
                    AlternativeSuggestion(
                        name="Tadım Çiğ Karışık Kuruyemiş",
                        brand="Tadım",
                        reason="Tuzsuz ve kızartılmamış doğal sağlıklı yağ ve protein kaynağı",
                    ),
                    AlternativeSuggestion(
                        name="Torku Tam Buğdaylı Sade Kraker",
                        brand="Torku",
                        reason="Glikoz-fruktoz şurubu içermeyen fırınlanmış alternatif",
                    ),
                )
            if any(w in name_lower for w in ("kola", "gazoz", "soğuk çay", "meyve suyu", "içecek", "cola", "soda")):
                return (
                    AlternativeSuggestion(
                        name="Beypazarı Doğal Maden Suyu",
                        brand="Beypazarı",
                        reason="Sıfır kalori, katkısız zengin doğal mineral kaynağı",
                    ),
                    AlternativeSuggestion(
                        name="Dimes %100 Sıkma Portakal Suyu",
                        brand="Dimes",
                        reason="İlave şeker ve sentetik renklendirici içermez",
                    ),
                )
            if any(w in name_lower for w in ("salam", "sosis", "sucuk", "nugget")):
                return (
                    AlternativeSuggestion(
                        name="Torku Geleneksel Fermente Kangal Sucuk",
                        brand="Torku",
                        reason="Mekanik ayrılmış et içermeyen dana eti formülü",
                    ),
                    AlternativeSuggestion(
                        name="Pınar Hindi Göğüs Füme",
                        brand="Pınar",
                        reason="Düşük doymuş yağ oranlı yüksek protein alternatifi",
                    ),
                )
            return (
                AlternativeSuggestion(
                    name="Tariş / Atatürk Orman Çiftliği Doğal Seri",
                    brand="Tariş",
                    reason="Katkı maddesi ve sentetik koruyucu içermeyen geleneksel üretim",
                ),
                AlternativeSuggestion(
                    name="Torku Sade Pancar Şekerli / Doğal Seçenek",
                    brand="Torku",
                    reason="Glikoz şurubu ve yapay tatlandırıcı içermeyen alternatif",
                ),
            )

        return (
            AlternativeSuggestion(
                name=f"{brand} Sade / Katkısız Seçenek",
                brand=brand,
                reason="Temiz içerikli ve dengeli besin profiline sahip ürün grubu",
            ),
            AlternativeSuggestion(
                name="Atatürk Orman Çiftliği Doğal Ürün Serisi",
                brand="AOÇ",
                reason="Geleneksel yöntemlerle üretilen katkısız referans gıda",
            ),
        )


class MetadataNormalizer:
    """Normalizes TGK allergens, legal producer names, quantities, and market chains."""

    @staticmethod
    def resolve_allergens(raw_allergens: str, ingredients_text: str) -> str:
        cleaned_raw = raw_allergens.strip()
        # If raw comes directly from Turkish TGK (no `en:` prefix tags), clean & keep
        if cleaned_raw and "en:" not in cleaned_raw.lower() and ":" not in cleaned_raw:
            no_dots = cleaned_raw.replace("...", "").replace("…", "").strip()
            if len(no_dots) >= 3:
                return no_dots

        detected: list[str] = []
        if cleaned_raw:
            for token in re.split(r"[,;]", cleaned_raw):
                tag = token.strip().lower()
                if ":" in tag:
                    tag = tag.split(":", 1)[1]
                mapped = ALLERGEN_TAG_TR_MAP.get(tag)
                if mapped and mapped not in detected:
                    detected.append(mapped)

        for regex, label in INGREDIENT_ALLERGEN_PATTERNS:
            if regex.search(ingredients_text) and label not in detected:
                detected.append(label)

        if detected:
            return ", ".join(detected)
        return "Bilinen alerjen bileşen içermez."

    @staticmethod
    def resolve_producer(
        brand: str, raw_producer: str
    ) -> str:
        cleaned = re.sub(r"\s+", " ", raw_producer).replace("...", "").strip()
        if (
            cleaned
            and len(cleaned) >= 4
            and "yerli üretici" not in cleaned.lower()
            and "bilinmeyen" not in cleaned.lower()
        ):
            # If OFF manufacturing_places only says country name ("Turkey"/"Türkiye"), upgrade to brand entity
            if normalize_ascii_tr(cleaned) not in ("turkiye", "turkey", "germany", "italy", "france", "poland"):
                return cleaned

        b_norm = normalize_ascii_tr(brand)
        for key, legal_name in BRAND_LEGAL_ENTITY_MAP.items():
            if b_norm == key or b_norm.startswith(f"{key} ") or key in b_norm.split():
                return legal_name
        return f"{brand} Gıda İşletmecisi"

    @staticmethod
    def resolve_net_quantity(*candidates: str) -> str:
        for text in candidates:
            if not text:
                continue
            cleaned = text.replace("...", "").strip()
            match = _QTY_EXTRACT_RE.search(cleaned)
            if match:
                return re.sub(r"\s+", " ", match.group(1)).strip()
            if 1 < len(cleaned) <= 24 and any(ch.isdigit() for ch in cleaned):
                return cleaned
        return "1 Paket"

    @staticmethod
    def resolve_market_chains(
        barcode: str,
        brand: str,
        cand_stores: Sequence[str],
        mf_chains: Sequence[str],
        strategy_chains: Sequence[str],
    ) -> tuple[str, ...]:
        ordered: list[str] = []

        def add_chain(name: str) -> None:
            if name and name not in ordered:
                ordered.append(name)

        for ch in mf_chains:
            add_chain(ch)
        for ch in strategy_chains:
            add_chain(ch)
        for raw_st in cand_stores:
            mapped = MARKET_CHAIN_CANONICAL_MAP.get(raw_st.strip().lower())
            if mapped:
                add_chain(mapped)

        if barcode.startswith("8695077"):
            add_chain("BİM")
        elif barcode.startswith("8699118"):
            add_chain("A101")
        elif barcode.startswith("8682214"):
            add_chain("ŞOK")

        b_norm = normalize_ascii_tr(brand)
        pl_chain = PRIVATE_LABEL_CHAIN_BY_BRAND.get(b_norm)
        if pl_chain:
            add_chain(pl_chain)

        return tuple(ordered)


class DatasetRepository:
    """Atomic JSON & parameterized SQLite writer with integrity_check verification."""

    CREATE_TABLE_SQL = """
    CREATE TABLE IF NOT EXISTS market_products (
        barcode TEXT PRIMARY KEY NOT NULL,
        product_name TEXT NOT NULL,
        brand TEXT NOT NULL,
        organic_score INTEGER NOT NULL,
        nova_group INTEGER NOT NULL,
        verdict TEXT NOT NULL,
        summary TEXT NOT NULL,
        ingredients_text TEXT NOT NULL,
        nutriments_json TEXT NOT NULL,
        allergens TEXT NOT NULL,
        market_chains_json TEXT NOT NULL,
        net_quantity TEXT NOT NULL,
        producer_legal_name TEXT NOT NULL,
        reference_price_try REAL,
        data_source TEXT NOT NULL,
        warnings_json TEXT NOT NULL,
        alternatives_json TEXT NOT NULL,
        ai_summary_json TEXT NOT NULL,
        updated_at INTEGER NOT NULL
    );
    """

    CREATE_INDEXES_SQL: tuple[str, ...] = (
        "CREATE INDEX IF NOT EXISTS idx_market_products_brand ON market_products(brand);",
        "CREATE INDEX IF NOT EXISTS idx_market_products_name ON market_products(product_name);",
        "CREATE INDEX IF NOT EXISTS idx_market_products_score ON market_products(organic_score);",
        "CREATE INDEX IF NOT EXISTS idx_market_products_nova ON market_products(nova_group);",
    )

    INSERT_PRODUCT_SQL = """
    INSERT OR REPLACE INTO market_products (
        barcode,
        product_name,
        brand,
        organic_score,
        nova_group,
        verdict,
        summary,
        ingredients_text,
        nutriments_json,
        allergens,
        market_chains_json,
        net_quantity,
        producer_legal_name,
        reference_price_try,
        data_source,
        warnings_json,
        alternatives_json,
        ai_summary_json,
        updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    """

    @staticmethod
    def save_json_snapshots(
        records: Sequence[MarketProductRecord], json_path: str
    ) -> None:
        os.makedirs(os.path.dirname(os.path.abspath(json_path)), exist_ok=True)
        tmp_path = f"{json_path}.tmp"
        payload = [rec.to_dict() for rec in records]
        with open(tmp_path, "w", encoding="utf-8") as fh:
            json.dump(payload, fh, ensure_ascii=False, indent=2)
        os.replace(tmp_path, json_path)

    @classmethod
    def save_sqlite_master(
        cls, records: Sequence[MarketProductRecord], db_path: str
    ) -> None:
        abs_db = os.path.abspath(db_path)
        os.makedirs(os.path.dirname(abs_db), exist_ok=True)
        tmp_db = f"{abs_db}.tmp"
        if os.path.exists(tmp_db):
            os.remove(tmp_db)

        now_ts = int(time.time())
        conn = sqlite3.connect(tmp_db, timeout=30.0)
        try:
            cur = conn.cursor()
            cur.execute("PRAGMA journal_mode=DELETE;")
            cur.execute("PRAGMA synchronous=FULL;")
            cur.execute(cls.CREATE_TABLE_SQL)
            for idx_sql in cls.CREATE_INDEXES_SQL:
                cur.execute(idx_sql)

            rows: list[tuple[Any, ...]] = []
            for rec in records:
                ai = rec.ai_summary_json
                ai_dict = ai.to_dict()
                rows.append(
                    (
                        rec.barcode,
                        rec.product_name,
                        rec.brand,
                        ai.organic_score,
                        ai.nova_group,
                        ai.verdict,
                        ai.summary,
                        ai.ingredients_text,
                        json.dumps(ai.nutriments.to_dict(), ensure_ascii=False),
                        ai.allergens,
                        json.dumps(list(ai.market_chains), ensure_ascii=False),
                        ai.net_quantity,
                        ai.producer_legal_name,
                        ai.reference_price_try,
                        ai.data_source,
                        json.dumps(list(ai.warnings), ensure_ascii=False),
                        json.dumps([a.to_dict() for a in ai.alternatives], ensure_ascii=False),
                        json.dumps(ai_dict, ensure_ascii=False),
                        now_ts,
                    )
                )

            cur.executemany(cls.INSERT_PRODUCT_SQL, rows)
            conn.commit()
            cur.execute("VACUUM;")
            integrity = cur.execute("PRAGMA integrity_check;").fetchone()
            if not integrity or str(integrity[0]).lower() != "ok":
                raise RuntimeError(f"SQLite integrity_check failed: {integrity}")
        finally:
            conn.close()

        os.replace(tmp_db, abs_db)
        if os.path.getsize(abs_db) <= 0:
            raise RuntimeError("Generated foodscore_master.db is 0 bytes!")


class KilerceMarketEtlPipeline:
    """SOLID orchestrator coordinating Discovery -> Verification -> Enrichment -> Persistence."""

    def __init__(
        self,
        registry: SourceRegistry,
        json_output_path: str,
        sqlite_output_path: str,
        min_required_records: int = 1300,
    ) -> None:
        self._registry = registry
        self._json_output_path = json_output_path
        self._sqlite_output_path = sqlite_output_path
        self._min_required_records = min_required_records

    @classmethod
    def create_default(
        cls,
        *,
        json_output_path: str,
        sqlite_output_path: str,
        min_required_records: int = 1300,
    ) -> tuple["KilerceMarketEtlPipeline", PooledHttpClient]:
        http_client = PooledHttpClient(pool_maxsize=32, cache_maxsize=6000)
        registry = SourceRegistry()
        tgk_seed_strategy = VerifiedTgkPrivateLabelStrategy()
        registry.register_discovery(tgk_seed_strategy)
        registry.register_discovery(
            OpenFoodFactsSearchSource(
                http_client=http_client,
                seed_snapshot_path=json_output_path,
                max_workers=6,
            )
        )
        registry.register_verifier(
            MarketFiyatiVerifierSource(
                http_client=http_client,
                max_workers=16,
                max_keyword_fallbacks=180,
            )
        )
        registry.register_enrichment(tgk_seed_strategy)
        registry.register_enrichment(
            MigrosRestEnrichmentStrategy(
                http_client=http_client,
                max_workers=8,
                max_on_demand_searches=380,
            )
        )
        registry.register_enrichment(
            CepteSokEnrichmentStrategy(
                http_client=http_client,
                max_workers=5,
                max_queries=160,
            )
        )
        registry.register_enrichment(
            OpenFoodFactsProductBatchStrategy(
                http_client=http_client,
                batch_size=46,
                max_batches=58,
                batch_interval_seconds=5.8,
            )
        )
        return (
            cls(
                registry=registry,
                json_output_path=json_output_path,
                sqlite_output_path=sqlite_output_path,
                min_required_records=min_required_records,
            ),
            http_client,
        )

    def _assemble_record(
        self,
        cand: RawDiscoveryCandidate,
        mf_info: MarketIdentityInfo | None,
        enrichments: Sequence[TgkEnrichmentInfo],
    ) -> MarketProductRecord | None:
        if not is_valid_gs1_barcode(cand.barcode):
            return None

        # 1. Resolve canonical product_name & brand (MarketFiyatı > Retail TGK > OFF)
        name_candidates = [
            mf_info.official_name if mf_info else "",
            *(e.official_name for e in enrichments),
            cand.product_name,
        ]
        product_name = next((n.strip() for n in name_candidates if is_valid_product_name(n)), "")
        if not product_name:
            return None

        brand_candidates = [
            mf_info.official_brand if mf_info else "",
            *(e.official_brand for e in enrichments),
            cand.brand,
        ]
        brand = next((b.strip() for b in brand_candidates if is_valid_brand_name(b)), "")
        if not brand:
            return None

        # 2. Resolve full untruncated ingredients_text (Retail Turkish TGK > OFF v2)
        ing_candidates = [
            *(e.ingredients_text for e in enrichments),
            clean_ingredients_text(cand.ingredients_text),
        ]
        ingredients_text = next(
            (ing for ing in ing_candidates if validate_full_ingredients(ing)),
            "",
        )
        if not ingredients_text:
            return None

        # 3. Resolve Atwater-validated 100g nutriments (Retail TGK > OFF v2 > OFF Search)
        nutriments: Nutriments100g | None = None
        for e in enrichments:
            if e.nutriments is not None and is_valid_atwater_nutrition(e.nutriments):
                nutriments = e.nutriments
                break
        if nutriments is None and is_valid_atwater_nutrition(cand.nutriments_raw):
            nutriments = normalize_nutriments(cand.nutriments_raw)
        if nutriments is None or not is_valid_atwater_nutrition(nutriments):
            return None

        # 4. Resolve allergens, producer, quantity, reference price, chains, and data_source
        raw_allergens = next(
            (e.allergens for e in enrichments if e.allergens),
            cand.allergens,
        )
        allergens = MetadataNormalizer.resolve_allergens(raw_allergens, ingredients_text)

        raw_producer = next(
            (e.producer_legal_name for e in enrichments if e.producer_legal_name),
            cand.producer_legal_name,
        )
        producer_legal_name = MetadataNormalizer.resolve_producer(brand, raw_producer)

        net_quantity = MetadataNormalizer.resolve_net_quantity(
            mf_info.net_quantity if mf_info else "",
            *(e.net_quantity for e in enrichments),
            cand.net_quantity,
            product_name,
        )

        price_candidates: list[float] = []
        if mf_info and mf_info.reference_price_try is not None:
            price_candidates.append(mf_info.reference_price_try)
        for e in enrichments:
            if e.reference_price_try is not None:
                price_candidates.append(e.reference_price_try)
        reference_price_try = price_candidates[0] if price_candidates else None

        strat_chains: list[str] = []
        for e in enrichments:
            for ch in e.market_chains:
                if ch not in strat_chains:
                    strat_chains.append(ch)

        market_chains = MetadataNormalizer.resolve_market_chains(
            barcode=cand.barcode,
            brand=brand,
            cand_stores=cand.stores,
            mf_chains=mf_info.market_chains if mf_info else (),
            strategy_chains=strat_chains,
        )

        sources_used: list[str] = []
        if mf_info is not None:
            sources_used.append(mf_info.source_tag)
        for e in enrichments:
            if e.source_tag and (e.ingredients_text or e.nutriments is not None):
                if e.source_tag not in sources_used:
                    sources_used.append(e.source_tag)
        if not sources_used:
            sources_used.append(cand.source_tag)
        data_source = "+".join(sources_used)

        raw_nova = next(
            (e.nova_group for e in enrichments if e.nova_group is not None),
            cand.nova_group,
        )

        score, nova, verdict, summary, warnings, alternatives = BiochemicalAnalyzer.analyze(
            name=product_name,
            brand=brand,
            ingredients_text=ingredients_text,
            nutriments=nutriments,
            raw_nova=raw_nova,
        )

        if "..." in summary or "…" in summary:
            return None

        payload = AiSummaryPayload(
            organic_score=score,
            nova_group=nova,
            verdict=verdict,
            summary=summary,
            warnings=warnings,
            alternatives=alternatives,
            ingredients_text=ingredients_text,
            nutriments=nutriments,
            allergens=allergens,
            market_chains=market_chains,
            net_quantity=net_quantity,
            producer_legal_name=producer_legal_name,
            reference_price_try=reference_price_try,
            data_source=data_source,
        )
        return MarketProductRecord(
            barcode=cand.barcode,
            product_name=product_name,
            brand=brand,
            ai_summary_json=payload,
        )

    def run(self) -> list[MarketProductRecord]:
        t_start = time.monotonic()
        try:
            # Step 1: Discover genuine GS1 barcodes
            discovered_map: dict[str, RawDiscoveryCandidate] = {}
            for src in self._registry.discovery_sources:
                logger.info("[1/4] Discovering barcodes via %s ...", src.source_name)
                for cand in src.discover():
                    if is_valid_gs1_barcode(cand.barcode) and cand.barcode not in discovered_map:
                        discovered_map[cand.barcode] = cand

            candidates = list(discovered_map.values())
            logger.info("-> Discovered %d unique Modulo-10 GS1 barcode candidates.", len(candidates))

            # Step 2: Verify against TÜBİTAK MarketFiyatı
            market_map: dict[str, MarketIdentityInfo] = {}
            for verifier in self._registry.market_verifiers:
                logger.info("[2/4] Verifying market chains & prices via %s ...", verifier.source_name)
                verified_chunk = verifier.verify_candidates(candidates)
                market_map.update(verified_chunk)
            logger.info("-> MarketFiyatı verified %d barcodes across official supermarket depots.", len(market_map))

            # Step 3: Execute all registered TGK enrichment strategies concurrently
            strategies = self._registry.enrichment_strategies
            logger.info(
                "[3/4] Running %d TGK enrichment strategies concurrently (%s) ...",
                len(strategies),
                ", ".join(s.source_name for s in strategies),
            )
            with ThreadPoolExecutor(max_workers=max(1, len(strategies))) as strat_pool:
                prep_futs = {
                    strat_pool.submit(strat.prepare_batch, candidates, market_map): strat.source_name
                    for strat in strategies
                }
                for fut in as_completed(prep_futs):
                    sname = prep_futs[fut]
                    try:
                        fut.result()
                        logger.info("   Strategy '%s' batch preparation finished.", sname)
                    except Exception as exc:
                        logger.error("   Strategy '%s' raised error: %s", sname, exc)

            # Step 4: Assemble, strictly validate (Jidoka), sort, and persist
            records_by_bc: dict[str, MarketProductRecord] = {}
            for cand in candidates:
                mf_info = market_map.get(cand.barcode)
                enrichments: list[TgkEnrichmentInfo] = []
                for strat in strategies:
                    info = strat.enrich(cand, mf_info)
                    if info is not None:
                        enrichments.append(info)
                rec = self._assemble_record(cand, mf_info, enrichments)
                if rec is not None:
                    records_by_bc[rec.barcode] = rec

            # Sort Turkish GS1 & MarketFiyatı-verified records first, then barcode
            final_records = sorted(
                records_by_bc.values(),
                key=lambda r: (
                    0 if r.ai_summary_json.market_chains else 1,
                    0 if r.barcode.startswith(("868", "869")) else 1,
                    r.barcode,
                ),
            )

            logger.info(
                "[4/4] Assembled %d strictly validated products (elapsed %.1fs).",
                len(final_records),
                time.monotonic() - t_start,
            )

            if len(final_records) < self._min_required_records:
                raise RuntimeError(
                    f"Jidoka minimum count gate failed: got {len(final_records)}, "
                    f"expected >= {self._min_required_records}"
                )

            DatasetRepository.save_json_snapshots(final_records, self._json_output_path)
            DatasetRepository.save_sqlite_master(final_records, self._sqlite_output_path)
            return final_records
        finally:
            self._registry.close_all()
