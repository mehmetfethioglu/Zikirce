"""Build compact pantry-matching index JSON for Cloudflare R2."""
import argparse
import json
import sqlite3
from pathlib import Path

DEFAULT_DB = Path(r"c:\Users\theak\Downloads\ym\kilerce_recipes.db")
DEFAULT_OUT = Path(r"c:\Users\theak\Downloads\ym\pantry_compact_index.json")


def build_compact_index(db_path: Path, out_path: Path) -> None:
    if not db_path.exists():
        raise FileNotFoundError(f"SQLite DB not found: {db_path}")

    conn = sqlite3.connect(str(db_path))
    cats: list[str] = []
    cat_map: dict[str, int] = {}
    tags: list[str] = []
    tag_map: dict[str, int] = {}
    recipes: list[list] = []

    query = (
        "SELECT id, kilerce_category, quality_score, required_tags_json "
        "FROM recipes ORDER BY quality_score DESC, id ASC"
    )
    for rid, kcat, qscore, req_json in conn.execute(query):
        cat_str = str(kcat or "").strip()
        if cat_str not in cat_map:
            cat_map[cat_str] = len(cats)
            cats.append(cat_str)

        req_tags = json.loads(req_json) if req_json else []
        tag_ids: list[int] = []
        seen_t: set[int] = set()
        for raw_tag in req_tags:
            t = str(raw_tag or "").strip().lower()
            if not t:
                continue
            if t not in tag_map:
                tag_map[t] = len(tags)
                tags.append(t)
            tid = tag_map[t]
            if tid not in seen_t:
                seen_t.add(tid)
                tag_ids.append(tid)

        recipes.append([rid, cat_map[cat_str], int(qscore or 0), tag_ids])

    conn.close()

    payload = {
        "v": 1,
        "cats": cats,
        "tags": tags,
        "recipes": recipes,
    }
    out_path.parent.mkdir(parents=True, exist_ok=True)
    encoded = json.dumps(payload, separators=(",", ":"), ensure_ascii=False)
    out_path.write_text(encoded, encoding="utf-8")
    size_kb = out_path.stat().st_size / 1024.0
    print(
        f"BUILT_INDEX recipes={len(recipes)} cats={len(cats)} "
        f"tags={len(tags)} size_kb={size_kb:.1f} out={out_path}"
    )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Build compact pantry matching index JSON for Cloudflare R2."
    )
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()
    build_compact_index(args.db, args.out)


if __name__ == "__main__":
    main()
