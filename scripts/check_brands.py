import urllib.request
import json
import ssl
import sys

sys.stdout.reconfigure(encoding='utf-8')

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

headers = {'User-Agent': 'OrganicScore - Android - Version 1.5 - https://organicscore.app'}

brands = ['dost', 'birsah', 'mis', 'aknaz', 'piyale', 'efsane', 'kerem', 'torku', 'ulker', 'eti', 'sutas', 'pinar']
for b in brands:
    url = f'https://world.openfoodfacts.org/api/v2/search?brands_tags={b}&countries_tags_en=turkey&fields=code,product_name,brands,ingredients_text&page_size=5'
    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=10, context=ctx) as r:
            d = json.loads(r.read().decode('utf-8'))
            count = d.get('count', 0)
            print(f"Brand {b.upper()}: {count} products found")
    except Exception as e:
        print(f"Brand {b} error:", e)
