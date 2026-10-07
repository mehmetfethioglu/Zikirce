import json
import sqlite3
import os
import sys

sys.stdout.reconfigure(encoding='utf-8')

with open('assets/data/top_turkiye_ai_snapshots.json', 'r', encoding='utf-8') as f:
    snapshots = json.load(f)
print('Total snapshots in json:', len(snapshots))

# Check brands distribution
brands = {}
for s in snapshots:
    b = s.get('brand', 'Bilinmeyen')
    brands[b] = brands.get(b, 0) + 1
sorted_brands = sorted(brands.items(), key=lambda x: x[1], reverse=True)[:15]
print('Top brands in top_turkiye_ai_snapshots.json:', sorted_brands)

# Check if BIM, A101, SOK brands exist
discount_brands = ['Dost', 'Birşah', 'Mis', 'Aknaz', 'Piyale', 'Efsane', 'Kerem', 'Saban', 'Tarabya', 'Pekit', 'Kaanlar', 'Torku', 'Ülker', 'Eti', 'Sütaş', 'Pınar']
for db in discount_brands:
    count = sum(1 for s in snapshots if db.lower() in (s.get('brand') or '').lower() or db.lower() in (s.get('product_name') or '').lower())
    print(f"Brand '{db}': {count} products found")

# Check foodscore_master.db
db_path = 'assets/data/foodscore_master.db'
if os.path.exists(db_path):
    print('\nfoodscore_master.db size:', os.path.getsize(db_path))
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    cur.execute("SELECT name FROM sqlite_master WHERE type='table';")
    tables = cur.fetchall()
    print('Tables in master db:', tables)
    for t in tables:
        cur.execute(f"SELECT count(*) FROM {t[0]}")
        print(f"Table {t[0]} count:", cur.fetchone()[0])
    conn.close()
