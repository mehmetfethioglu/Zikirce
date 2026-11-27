"""Export Kilerce 23,933 recipes from SQLite into D1-safe SQL chunks."""
import argparse
import csv
import json
import re
import sqlite3
import tempfile
from pathlib import Path

DEFAULT_DB = Path(r"c:\Users\theak\Downloads\ym\kilerce_recipes.db")
DEFAULT_MAPPING = Path(r"G:\Drive'ım\Kilerce_Recipe_Covers\manifest_photo_v3_r2_mapping.csv")
DEFAULT_OUT_DIR = Path(r"c:\Users\theak\Downloads\ym\d1_export_chunks")
DEFAULT_SCHEMA = (
    Path(__file__).resolve().parents[2]
    / "edge_worker"
    / "migrations"
    / "0001_init_recipes_and_entitlements.sql"
)

TR_TRANS = str.maketrans("çğıöşüÇĞİIÖŞÜâîûÂÎÛ", "cgiosucgiiosuaiuaiu")

RECIPE_COLS = (
    "id", "source", "title", "subtitle", "emoji", "category", "kilerce_category",
    "region_id", "prep_minutes", "cook_minutes", "total_minutes", "servings_count",
    "servings_unit", "servings_label", "difficulty", "cooking_method",
    "contains_gluten", "contains_lactose", "is_vegan", "is_vegetarian",
    "has_margarine", "is_refined_sugar_free", "is_healthy_clean",
    "base_health_score", "quality_score", "clean_label_badges_json",
    "diet_tags_json", "meal_slots_json", "required_tags_json",
    "optional_tags_json", "ingredients_json", "steps_json",
    "image_rel_path", "search_fold",
)

ING_COLS = (
    "id", "recipe_id", "seq", "display", "name", "amount", "amount_max",
    "unit", "note", "tag", "is_optional", "is_pantry_staple",
)


def turkish_fold(text: str) -> str:
    folded = text.translate(TR_TRANS).lower()
    return re.sub(r"[^a-z0-9]+", " ", folded).strip()


def sql_literal(val) -> str:
    if val is None:
        return "NULL"
    if isinstance(val, bool):
        return "1" if val else "0"
    if isinstance(val, (int, float)):
        return repr(val)
    s = str(val).replace("\x00", "").replace("'", "''")
    return f"'{s}'"


def load_image_mapping(csv_path: Path) -> dict[str, str]:
    if not csv_path.exists():
        raise FileNotFoundError(f"Mapping CSV not found: {csv_path}")
    mapping: dict[str, str] = {}
    with csv_path.open("r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            rid = (row.get("id") or "").strip()
            rel = (row.get("rel_path") or "").strip()
            if rid and rel:
                mapping[rid] = rel
    return mapping


def write_batch_inserts(out_f, table: str, cols: tuple[str, ...], rows: list[tuple], batch_size: int = 25):
    col_list = ", ".join(cols)
    for idx in range(0, len(rows), batch_size):
        slice_rows = rows[idx : idx + batch_size]
        values_sql = ",\n".join(
            "(" + ", ".join(sql_literal(v) for v in row) + ")"
            for row in slice_rows
        )
        out_f.write(f"INSERT OR REPLACE INTO {table} ({col_list}) VALUES\n{values_sql};\n")


def export_chunks(
    db_path: Path,
    mapping_csv: Path,
    out_dir: Path,
    recipes_per_chunk: int = 500,
) -> tuple[list[Path], int, int]:
    if not db_path.exists():
        raise FileNotFoundError(f"SQLite DB not found: {db_path}")

    mapping = load_image_mapping(mapping_csv)
    out_dir.mkdir(parents=True, exist_ok=True)
    for old_sql in out_dir.glob("chunk_*.sql"):
        old_sql.unlink()

    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()

    db_recipe_cols = RECIPE_COLS[:-2]
    recipes_rows = cur.execute(
        f"SELECT {', '.join(db_recipe_cols)} FROM recipes ORDER BY quality_score DESC, id ASC"
    ).fetchall()

    missing_images = [r["id"] for r in recipes_rows if r["id"] not in mapping]
    if missing_images:
        conn.close()
        raise ValueError(
            f"{len(missing_images)} recipes missing in mapping CSV, first 5: {missing_images[:5]}"
        )

    ing_by_recipe: dict[str, list[tuple]] = {}
    ing_total = 0
    for ir in cur.execute(f"SELECT {', '.join(ING_COLS)} FROM recipe_ingredients ORDER BY id ASC"):
        ing_total += 1
        rid = ir["recipe_id"]
        ing_by_recipe.setdefault(rid, []).append(tuple(ir[c] for c in ING_COLS))

    chunk_files: list[Path] = []
    for chunk_idx, start in enumerate(range(0, len(recipes_rows), recipes_per_chunk), start=1):
        chunk_recipes = recipes_rows[start : start + recipes_per_chunk]
        chunk_path = out_dir / f"chunk_{chunk_idx:03d}.sql"
        recipe_tuples: list[tuple] = []
        fts_tuples: list[tuple] = []
        ing_tuples: list[tuple] = []

        for r in chunk_recipes:
            rid = r["id"]
            rel_path = mapping[rid]
            ing_items = json.loads(r["ingredients_json"])
            ing_names = " ".join(str(item.get("name") or "") for item in ing_items if isinstance(item, dict))
            search_fold = turkish_fold(f"{r['title']} {r['category']} {r['kilerce_category']} {ing_names}")
            recipe_tuples.append(tuple(r[c] for c in db_recipe_cols) + (rel_path, search_fold))
            fts_tuples.append((rid, r["title"], ing_names, search_fold))
            ing_tuples.extend(ing_by_recipe.get(rid, ()))

        with chunk_path.open("w", encoding="utf-8", newline="\n") as out_f:
            out_f.write(f"-- Kilerce D1 chunk {chunk_idx:03d} ({len(recipe_tuples)} recipes)\n")
            write_batch_inserts(out_f, "recipes", RECIPE_COLS, recipe_tuples, batch_size=20)
            if ing_tuples:
                write_batch_inserts(out_f, "recipe_ingredients", ING_COLS, ing_tuples, batch_size=40)
            write_batch_inserts(
                out_f,
                "recipes_fts",
                ("recipe_id", "title", "ingredients_text", "search_fold"),
                fts_tuples,
                batch_size=40,
            )
        chunk_files.append(chunk_path)

    conn.close()
    print(f"EXPORT_OK chunks={len(chunk_files)} recipes={len(recipes_rows)} ingredients={ing_total} out_dir={out_dir}")
    return chunk_files, len(recipes_rows), ing_total


def verify_local_sqlite(schema_path: Path, chunk_files: list[Path], expected_recipes: int, expected_ings: int) -> None:
    if not schema_path.exists():
        raise FileNotFoundError(f"Schema SQL not found: {schema_path}")
    with tempfile.TemporaryDirectory() as tmpdir:
        test_db = Path(tmpdir) / "d1_verify.sqlite"
        conn = sqlite3.connect(str(test_db))
        conn.executescript(schema_path.read_text(encoding="utf-8"))
        for cf in chunk_files:
            sql_text = cf.read_text(encoding="utf-8")
            if "BEGIN TRANSACTION" in sql_text.upper() or "\nCOMMIT;" in sql_text.upper():
                raise ValueError(f"D1-unsafe transaction keyword found in {cf.name}")
            conn.executescript(sql_text)

        rec_count = conn.execute("SELECT COUNT(*) FROM recipes").fetchone()[0]
        ing_count = conn.execute("SELECT COUNT(*) FROM recipe_ingredients").fetchone()[0]
        fts_count = conn.execute("SELECT COUNT(*) FROM recipes_fts").fetchone()[0]
        fts_hits = conn.execute(
            "SELECT r.id, r.title, r.image_rel_path FROM recipes r "
            "INNER JOIN recipes_fts f ON f.recipe_id = r.id "
            "WHERE recipes_fts MATCH 'karniyarik*' LIMIT 3"
        ).fetchall()
        conn.close()

        assert rec_count == expected_recipes, f"Expected {expected_recipes} recipes, got {rec_count}"
        assert ing_count == expected_ings, f"Expected {expected_ings} ingredients, got {ing_count}"
        assert fts_count == expected_recipes, f"Expected {expected_recipes} fts rows, got {fts_count}"
        assert len(fts_hits) > 0, "Expected Turkish-folded FTS query 'karniyarik*' to return results"
        print(f"LOCAL_VERIFY_OK RECIPES={rec_count} INGREDIENTS={ing_count} FTS={fts_count} SAMPLE_HIT={fts_hits[0]}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Export Kilerce SQLite recipes to Cloudflare D1 SQL chunks.")
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--mapping", type=Path, default=DEFAULT_MAPPING)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    parser.add_argument("--schema", type=Path, default=DEFAULT_SCHEMA)
    parser.add_argument("--recipes-per-chunk", type=int, default=500)
    parser.add_argument("--verify-local", action="store_true")
    args = parser.parse_args()

    chunk_files, rec_total, ing_total = export_chunks(
        args.db, args.mapping, args.out_dir, recipes_per_chunk=args.recipes_per_chunk
    )
    if args.verify_local:
        verify_local_sqlite(args.schema, chunk_files, rec_total, ing_total)


if __name__ == "__main__":
    main()
