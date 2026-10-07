import urllib.request
import json
import ssl
import sys

sys.stdout.reconfigure(encoding='utf-8')

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

# Let's inspect what OpenFoodFacts has for Turkish products when we filter for valid ingredients!
# Let's check how many products in OFF have ingredients_text and barcode in Turkey!
def check_off_turkey():
    url = (
        "https://world.openfoodfacts.org/api/v2/search?"
        "countries_tags_en=turkey&"
        "fields=code,product_name,product_name_tr,brands,ingredients_text_tr,ingredients_text,nutriments,nova_group&"
        "page_size=20&page=1"
    )
    headers = {'User-Agent': 'OrganicScoreApp/1.0 (contact@organicscore.app)'}
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=10, context=ctx) as r:
        data = json.loads(r.read().decode('utf-8'))
        print("OFF Turkey total count:", data.get('count'))
        products = data.get('products', [])
        with_ing = [p for p in products if p.get('ingredients_text_tr') or p.get('ingredients_text')]
        print(f"OFF Turkey sample: {len(products)} fetched, {len(with_ing)} have ingredients.")
        for p in with_ing[:3]:
            print("OFF Sample:", p.get('code'), p.get('product_name_tr') or p.get('product_name'), "Brand:", p.get('brands'))
            print("  Ing:", (p.get('ingredients_text_tr') or p.get('ingredients_text'))[:100])

if __name__ == '__main__':
    check_off_turkey()
