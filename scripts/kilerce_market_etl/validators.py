"""Pure deterministic GS1 Modulo-10, Atwater nutrition, and TGK ingredient validators.

Zero I/O, zero side effects (SRP). Depends only on stdlib and contracts.py.
"""

from __future__ import annotations

import html
import math
import re
from typing import Any, Mapping

from .contracts import Nutriments100g

_HTML_TAG_RE = re.compile(r"<[^>]+>")
_MULTI_SPACE_RE = re.compile(r"\s+")
_LEADING_ING_LABEL_RE = re.compile(
    r"^\s*(?:içindekiler|icindekiler|ingredients)\s*[:\-–]\s*",
    re.IGNORECASE,
)
_CYRILLIC_ARABIC_RE = re.compile(r"[\u0400-\u04FF\u0600-\u06FF]")
_QUANTITY_RE = re.compile(
    r"(?:(\d+)\s*[xX*]\s*)?(\d+(?:[.,]\d+)?)\s*"
    r"(kg|gr|g|mg|lt|l|ml|cl|adet|li|lü|lu|paket)\b",
    re.IGNORECASE,
)

_FORBIDDEN_PLACEHOLDERS: tuple[str, ...] = (
    "yerli üretici",
    "yerli uretici",
    "bilinmeyen marka",
    "yerli marka",
    "bilinmeyen üretici",
    "bilinmiyor",
    "belirtilmemiş",
    "belirtilmemis",
    "açık veritabanı ile eşleşti",
    "içindekiler bilgisi bulunmamaktadır",
    "ürün bilgisi bulunamadı",
    "markasız",
    "unknown",
    "undefined",
)

_EXACT_FORBIDDEN_VALUES: frozenset[str] = frozenset(
    {"", "-", "--", "n/a", "na", "none", "null", "yok", "uht", "su"}
)

_OCR_NUTRITION_PHRASES: tuple[str, ...] = (
    "enerji ve besin",
    "besin değerleri",
    "besin öğeleri",
    "referans alım",
    "porsiyon için",
    "100 g için enerji",
    "nutrition facts",
    "per 100g",
)

_OCR_NUTRITION_HEADERS: tuple[str, ...] = (
    "karbonhidrat",
    "doymuş yağ",
    "doymus yag",
    "enerji (kj",
    "kcal/100",
    "lif (g",
)

_TR_CHAR_MAP = str.maketrans(
    {
        "ç": "c",
        "ğ": "g",
        "ı": "i",
        "İ": "i",
        "ö": "o",
        "ş": "s",
        "ü": "u",
        "Ç": "c",
        "Ğ": "g",
        "Ö": "o",
        "Ş": "s",
        "Ü": "u",
        "â": "a",
        "î": "i",
        "û": "u",
    }
)


def is_valid_gs1_barcode(bc: str | int | None) -> bool:
    """Validate genuine EAN-8 or EAN-13 GS1 Modulo-10 barcode.

    - Rejects fake sequential series `8690772000*`.
    - Rejects 13-digit store-internal variable-weight PLUs `20*`..`29*`.
    - Preserves genuine 8-digit EAN-8 barcodes with valid Modulo-10 check digits.
    """
    if bc is None:
        return False
    code = str(bc).strip()
    if not code.isdigit():
        return False
    length = len(code)
    if length not in (8, 13):
        return False
    if len(set(code)) == 1:
        return False
    if code.startswith("8690772000"):
        return False
    if length == 13:
        prefix2 = int(code[:2])
        if 20 <= prefix2 <= 29:
            return False
        if code.startswith("000000"):
            return False

    weighted_sum = sum(
        int(ch) * (3 if idx % 2 == 0 else 1)
        for idx, ch in enumerate(reversed(code[:-1]))
    )
    expected_check = (10 - (weighted_sum % 10)) % 10
    return expected_check == int(code[-1])


def _parse_float(val: Any) -> float | None:
    if val is None or isinstance(val, bool):
        return None
    if isinstance(val, (int, float)):
        num = float(val)
        return num if math.isfinite(num) else None
    text = str(val).strip().replace(",", ".")
    text = re.sub(r"^[<>~≈\s]+", "", text)
    match = re.match(r"^[-+]?\d+(?:\.\d+)?", text)
    if not match:
        return None
    try:
        num = float(match.group(0))
    except ValueError:
        return None
    return num if math.isfinite(num) else None


def normalize_nutriments(
    nutr: Mapping[str, Any] | Nutriments100g | None,
) -> Nutriments100g | None:
    """Convert raw OFF/Migros/ŞOK or canonical 100g dict into Nutriments100g."""
    if isinstance(nutr, Nutriments100g):
        return nutr
    if not isinstance(nutr, Mapping) or not nutr:
        return None

    def pick(*keys: str) -> float | None:
        for key in keys:
            if key in nutr and nutr[key] is not None:
                parsed = _parse_float(nutr[key])
                if parsed is not None:
                    return parsed
        return None

    kcal = pick("energy_kcal", "energy-kcal_100g", "energy-kcal", "energyKcal")
    if kcal is None:
        kj = pick("energy-kj_100g", "energy_kj", "energyKj")
        if kj is None:
            e_unit = str(nutr.get("energy_unit") or "kj").strip().lower()
            raw_e = pick("energy_100g", "energy")
            if raw_e is not None:
                if e_unit == "kcal":
                    kcal = raw_e
                else:
                    kj = raw_e
        if kj is not None and kcal is None:
            kcal = kj / 4.184

    fat = pick("fat_g", "fat_100g", "fat")
    sat_fat = pick("saturated_fat_g", "saturated-fat_100g", "saturated-fat", "saturatedFat")
    carbs = pick("carbs_g", "carbohydrates_100g", "carbohydrates", "carbohydrate")
    sugars = pick("sugars_g", "sugars_100g", "sugars", "glucose")
    fiber = pick("fiber_g", "fiber_100g", "fiber", "dietaryFiber")
    protein = pick("protein_g", "proteins_100g", "proteins", "protein")
    salt = pick("salt_g", "salt_100g", "salt")
    if salt is None:
        sodium = pick("sodium_100g", "sodium")
        if sodium is not None:
            salt = sodium * 2.5

    # Require energy_kcal and at least two primary macronutrients to avoid hollow records
    present_macros = sum(x is not None for x in (fat, carbs, protein))
    if kcal is None or present_macros < 2:
        return None

    return Nutriments100g(
        energy_kcal=kcal,
        fat_g=fat if fat is not None else 0.0,
        saturated_fat_g=sat_fat if sat_fat is not None else 0.0,
        carbs_g=carbs if carbs is not None else 0.0,
        sugars_g=sugars if sugars is not None else 0.0,
        fiber_g=fiber if fiber is not None else 0.0,
        protein_g=protein if protein is not None else 0.0,
        salt_g=salt if salt is not None else 0.0,
    )


def is_valid_atwater_nutrition(
    nutr: Mapping[str, Any] | Nutriments100g | None,
) -> bool:
    """Validate 100g nutritional profile against physical & Atwater thermodynamic laws.

    - Rejects non-finite, negative, or >100g single-macro values.
    - Enforces macro total <= 102g per 100g.
    - For declared energy <= 5 kcal, enforces <= 15 kcal absolute difference from Atwater.
    - Supports polyol metabolic factor tolerance (0.2..2.4 kcal/g on non-sugar carbs).
    """
    parsed = normalize_nutriments(nutr)
    if parsed is None:
        return False

    values = (
        parsed.energy_kcal,
        parsed.fat_g,
        parsed.saturated_fat_g,
        parsed.carbs_g,
        parsed.sugars_g,
        parsed.fiber_g,
        parsed.protein_g,
        parsed.salt_g,
    )
    if any(not math.isfinite(v) or v < 0.0 for v in values):
        return False

    if parsed.energy_kcal > 920.0:
        return False

    macros = (
        parsed.fat_g,
        parsed.saturated_fat_g,
        parsed.carbs_g,
        parsed.sugars_g,
        parsed.fiber_g,
        parsed.protein_g,
        parsed.salt_g,
    )
    if any(m > 100.0 for m in macros):
        return False

    # Sub-component invariants (allowing 0.5g label rounding tolerance)
    if parsed.saturated_fat_g > parsed.fat_g + 0.5:
        return False
    if parsed.sugars_g > parsed.carbs_g + 0.5:
        return False

    # Total dry-matter macro mass per 100g <= 102g
    macro_mass = (
        parsed.fat_g
        + parsed.carbs_g
        + parsed.fiber_g
        + parsed.protein_g
        + parsed.salt_g
    )
    if macro_mass > 102.0:
        return False

    standard_kcal = (
        9.0 * parsed.fat_g
        + 4.0 * parsed.carbs_g
        + 2.0 * parsed.fiber_g
        + 4.0 * parsed.protein_g
    )

    polyols_g = 0.0
    if isinstance(nutr, Mapping):
        raw_poly = _parse_float(nutr.get("polyols_100g") or nutr.get("polyols"))
        if raw_poly is not None and raw_poly > 0.0:
            polyols_g = min(raw_poly, max(0.0, parsed.carbs_g - parsed.sugars_g))

    non_sugar_carbs = max(0.0, parsed.carbs_g - parsed.sugars_g)
    # Polyol lower-bound energy (erythritol/polyols yield ~0.2..2.4 kcal/g instead of 4 kcal/g)
    polyol_adjusted_min_kcal = (
        9.0 * parsed.fat_g
        + 4.0 * min(parsed.sugars_g, parsed.carbs_g)
        + (0.2 * polyols_g if polyols_g > 0 else 2.4 * non_sugar_carbs)
        + 2.0 * parsed.fiber_g
        + 4.0 * parsed.protein_g
    )

    # Low-calorie strictness: <= 5 kcal requires <= 15 kcal absolute Atwater deviation
    if parsed.energy_kcal <= 5.0:
        effective_ref = polyol_adjusted_min_kcal if polyols_g > 0 else standard_kcal
        return abs(parsed.energy_kcal - effective_ref) <= 15.0

    # Normal foods (> 5 kcal): allow label rounding, organic acids (+25 kcal), & polyol tolerance
    max_allowed_kcal = max(standard_kcal * 1.28 + 20.0, standard_kcal + 28.0)
    min_allowed_kcal = max(0.0, polyol_adjusted_min_kcal * 0.70 - 20.0)
    return min_allowed_kcal <= parsed.energy_kcal <= max_allowed_kcal


def clean_ingredients_text(text: str | None) -> str:
    """Clean HTML entities/tags and whitespace without ever truncating content."""
    if not text or not isinstance(text, str):
        return ""
    cleaned = html.unescape(text)
    cleaned = _HTML_TAG_RE.sub(" ", cleaned)
    cleaned = cleaned.replace("\r", " ").replace("\n", " ").replace("\t", " ")
    cleaned = _LEADING_ING_LABEL_RE.sub("", cleaned)
    cleaned = _MULTI_SPACE_RE.sub(" ", cleaned).strip()
    return cleaned


def validate_full_ingredients(text: str | None) -> bool:
    """Ensure ingredients text is complete, untruncated, non-placeholder, and non-OCR-noise."""
    if not text or not isinstance(text, str):
        return False
    cleaned = clean_ingredients_text(text)
    if len(cleaned) < 6:
        return False

    lower = cleaned.lower()
    if lower in _EXACT_FORBIDDEN_VALUES:
        return False

    # Strict anti-truncation check (`[:160]`, `...`, `…`, dangling punctuation, unclosed parens)
    if "..." in cleaned or "…" in cleaned:
        return False
    if cleaned.endswith((",", "(", "[", "/", ":", ";", "-")):
        return False
    if cleaned.count("(") != cleaned.count(")"):
        return False
    if cleaned.count("[") != cleaned.count("]"):
        return False

    for phrase in _FORBIDDEN_PLACEHOLDERS:
        if phrase in lower:
            return False

    for ocr_phrase in _OCR_NUTRITION_PHRASES:
        if ocr_phrase in lower:
            return False

    ocr_header_hits = sum(1 for hdr in _OCR_NUTRITION_HEADERS if hdr in lower)
    if ocr_header_hits >= 2:
        return False

    # Reject Cyrillic/Arabic packaging OCR dumps
    if _CYRILLIC_ARABIC_RE.search(cleaned):
        return False

    alpha_count = sum(1 for ch in cleaned if ch.isalpha())
    if alpha_count < 5 or (alpha_count / len(cleaned)) < 0.48:
        return False

    return True


def is_valid_brand_name(brand: str | None) -> bool:
    """Reject empty or placeholder brand names (`Yerli Üretici`, `Bilinmeyen Marka`, etc.)."""
    if not brand or not isinstance(brand, str):
        return False
    cleaned = _MULTI_SPACE_RE.sub(" ", html.unescape(_HTML_TAG_RE.sub(" ", brand))).strip()
    if len(cleaned) < 2 or len(cleaned) > 80:
        return False
    lower = cleaned.lower()
    if lower in _EXACT_FORBIDDEN_VALUES:
        return False
    if "..." in cleaned or "…" in cleaned:
        return False
    return not any(phrase in lower for phrase in _FORBIDDEN_PLACEHOLDERS)


def is_valid_product_name(name: str | None) -> bool:
    """Reject empty, truncated, or placeholder product names."""
    if not name or not isinstance(name, str):
        return False
    cleaned = _MULTI_SPACE_RE.sub(" ", html.unescape(_HTML_TAG_RE.sub(" ", name))).strip()
    if len(cleaned) < 3 or len(cleaned) > 180:
        return False
    lower = cleaned.lower()
    if lower in _EXACT_FORBIDDEN_VALUES:
        return False
    if "..." in cleaned or "…" in cleaned:
        return False
    if _CYRILLIC_ARABIC_RE.search(cleaned):
        return False
    return not any(phrase in lower for phrase in _FORBIDDEN_PLACEHOLDERS)


def normalize_ascii_tr(text: str | None) -> str:
    """Lowercase ASCII-folded Turkish string for deterministic brand/product matching."""
    if not text:
        return ""
    folded = text.translate(_TR_CHAR_MAP).lower()
    folded = re.sub(r"[^a-z0-9\s]", " ", folded)
    return _MULTI_SPACE_RE.sub(" ", folded).strip()


def parse_quantity_to_base_unit(text: str | None) -> tuple[float, str] | None:
    """Normalize package quantity (e.g. '1 Lt' -> (1000.0, 'ml'), '6x200 ml' -> (1200.0, 'ml'))."""
    if not text:
        return None
    matches = list(_QUANTITY_RE.finditer(text))
    if not matches:
        return None
    match = matches[-1]
    mult = float(match.group(1)) if match.group(1) else 1.0
    amount = float(match.group(2).replace(",", "."))
    unit = match.group(3).lower()
    total = mult * amount
    if total <= 0:
        return None
    if unit == "kg":
        return total * 1000.0, "g"
    if unit in ("g", "gr"):
        return total, "g"
    if unit == "mg":
        return total / 1000.0, "g"
    if unit in ("l", "lt"):
        return total * 1000.0, "ml"
    if unit == "cl":
        return total * 10.0, "ml"
    if unit == "ml":
        return total, "ml"
    return total, "count"
