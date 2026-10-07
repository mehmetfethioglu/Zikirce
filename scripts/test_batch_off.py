import urllib.request
import json
import ssl
import sys
import time

sys.stdout.reconfigure(encoding='utf-8')
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

headers = {
    'User-Agent': 'OrganicScoreApp - Android - Version 2.0 (contact@organicscore.app)'
}

def test_fetch(pages=10):
    total = 0
    with_ing = 0
    for p in range(1, pages + 1):
        url = f"https://world.openfoodfacts.org/api/v2/search?countries_tags_en=turkey&fields=code,product_name_tr,product_name,brands,ingredients_text_tr,ingredients_text,nutriments,nova_group&page_size=100&page={p}"
        try:
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=20, context=ctx) as r:
                data = json.loads(r.read().decode('utf-8'))
                prods = data.get('products', [])
                total += len(prods)
                for pr in prods:
                    ing = pr.get('ingredients_text_tr') or pr.get('ingredients_text')
                    code = pr.get('code')
                    name = pr.get('product_name_tr') or pr.get('product_name')
                    if code and name and ing and len(ing.strip()) > 8:
                        with_ing += 1
            print(f"Page {p} OK: fetched {len(prods)}, total valid with ingredients: {with_ing}")
            time.sleep(0.8)
        except Exception as e:
            print(f"Page {p} error: {e}")
            time.sleep(2)
    print(f"\nFinal: {total} fetched, {with_ing} with valid ingredients")

if __name__ == '__main__':
    test_fetch(10)
