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

page_size = 100
total_inspected = 0
valid_with_ingredients = 0
brands_count = {}

for page in range(1, 6):
    url = f"https://world.openfoodfacts.org/api/v2/search?countries_tags_en=turkey&fields=code,product_name_tr,product_name,brands,ingredients_text_tr,ingredients_text,nutriments,nova_group&page_size={page_size}&page={page}"
    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=15, context=ctx) as r:
            data = json.loads(r.read().decode('utf-8'))
            products = data.get('products', [])
            total_inspected += len(products)
            for p in products:
                barcode = p.get('code')
                name = p.get('product_name_tr') or p.get('product_name')
                brand = (p.get('brands') or '').split(',')[0].strip()
                ing = p.get('ingredients_text_tr') or p.get('ingredients_text')
                
                if barcode and name and ing and len(ing) > 10:
                    valid_with_ingredients += 1
                    brands_count[brand] = brands_count.get(brand, 0) + 1
        print(f"Page {page}: {len(products)} products, cumulative valid with ingredients: {valid_with_ingredients}")
        time.sleep(1)
    except Exception as e:
        print(f"Page {page} error: {e}")
        time.sleep(2)

print(f"\nTotal Inspected: {total_inspected}, Valid With Ingredients: {valid_with_ingredients}")
top_b = sorted(brands_count.items(), key=lambda x: x[1], reverse=True)[:15]
print("Top Brands with clean ingredients:", top_b)
