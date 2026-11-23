"""CLI entrypoint and backward-compatible facade for Kilerce Market ETL.

Generates:
1. `assets/data/top_turkiye_ai_snapshots.json`
2. `assets/data/foodscore_master.db` (`market_products` + indexes + `PRAGMA integrity_check=ok`)
"""

from __future__ import annotations

import argparse
import logging
import os
import sys
from typing import Any, Mapping

# Ensure sibling package `kilerce_market_etl` is importable regardless of working directory
_SCRIPTS_DIR = os.path.dirname(os.path.abspath(__file__))
if _SCRIPTS_DIR not in sys.path:
    sys.path.insert(0, _SCRIPTS_DIR)

from kilerce_market_etl import (  # noqa: E402
    NATURAL_FOOD_TERMS,
    ULTRA_PROCESSED_TERMS,
    BiochemicalAnalyzer,
    KilerceMarketEtlPipeline,
    Nutriments100g,
    clean_ingredients_text,
    is_valid_atwater_nutrition,
    is_valid_gs1_barcode,
    normalize_nutriments,
    validate_full_ingredients,
)


def analyze_food_biochemistry(
    name: str,
    brand: str,
    ingredients: str,
    nutriments: Mapping[str, Any] | None = None,
    raw_nova: int | None = None,
) -> dict[str, Any]:
    """LSP-compatible biochemical scoring facade with full untruncated ingredients."""
    clean_ing = clean_ingredients_text(ingredients)
    parsed_nutr = normalize_nutriments(nutriments) if nutriments else None
    if parsed_nutr is None:
        parsed_nutr = Nutriments100g(
            energy_kcal=0.0,
            fat_g=0.0,
            saturated_fat_g=0.0,
            carbs_g=0.0,
            sugars_g=0.0,
            fiber_g=0.0,
            protein_g=0.0,
            salt_g=0.0,
        )

    score, nova, verdict, summary, warnings, alternatives = BiochemicalAnalyzer.analyze(
        name=name,
        brand=brand,
        ingredients_text=clean_ing,
        nutriments=parsed_nutr,
        raw_nova=raw_nova,
    )
    return {
        "organic_score": score,
        "nova_group": nova,
        "verdict": verdict,
        "summary": summary,
        "warnings": list(warnings),
        "alternatives": [alt.to_dict() for alt in alternatives],
        "ingredients_text": clean_ing,
        "nutriments": parsed_nutr.to_dict(),
    }


def build_complete_dataset(
    max_pages: int = 35,
    *,
    min_required_records: int = 1300,
    json_output_path: str | None = None,
    sqlite_output_path: str | None = None,
) -> int:
    """Execute the full live Turkish market ETL pipeline and persist JSON + SQLite assets."""
    del max_pages  # Preserved for backward CLI/caller signature compatibility (LSP)

    repo_root = os.path.abspath(os.path.join(_SCRIPTS_DIR, ".."))
    json_path = json_output_path or os.path.join(
        repo_root, "assets", "data", "top_turkiye_ai_snapshots.json"
    )
    db_path = sqlite_output_path or os.path.join(
        repo_root, "assets", "data", "foodscore_master.db"
    )

    pipeline, http_client = KilerceMarketEtlPipeline.create_default(
        json_output_path=json_path,
        sqlite_output_path=db_path,
        min_required_records=min_required_records,
    )
    try:
        records = pipeline.run()
        return len(records)
    finally:
        http_client.close()


def main(argv: list[str] | None = None) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")

    parser = argparse.ArgumentParser(
        description="Build verified Turkish supermarket product JSON & SQLite database."
    )
    parser.add_argument(
        "--min-records",
        type=int,
        default=1300,
        help="Minimum strictly validated GS1 products required (default: 1300).",
    )
    parser.add_argument(
        "--json-out",
        type=str,
        default=None,
        help="Override output path for top_turkiye_ai_snapshots.json.",
    )
    parser.add_argument(
        "--db-out",
        type=str,
        default=None,
        help="Override output path for foodscore_master.db.",
    )
    args = parser.parse_args(argv)

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%H:%M:%S",
    )

    total = build_complete_dataset(
        min_required_records=args.min_records,
        json_output_path=args.json_out,
        sqlite_output_path=args.db_out,
    )
    logging.info("Completed Kilerce Market ETL successfully: %d verified products.", total)
    return 0


__all__ = [
    "NATURAL_FOOD_TERMS",
    "ULTRA_PROCESSED_TERMS",
    "analyze_food_biochemistry",
    "build_complete_dataset",
    "is_valid_atwater_nutrition",
    "is_valid_gs1_barcode",
    "main",
    "validate_full_ingredients",
]

if __name__ == "__main__":
    raise SystemExit(main())
