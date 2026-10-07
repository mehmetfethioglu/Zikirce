import urllib.request
import json
import ssl
import sys

sys.stdout.reconfigure(encoding='utf-8')

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    'Accept': 'application/json',
    'Accept-Language': 'tr-TR,tr;q=0.9',
}

# Test search with keyword 'sut'
url = 'https://www.migros.com.tr/rest/products/search?q=sut'
req_search = urllib.request.Request(url, headers=headers)
with urllib.request.urlopen(req_search, timeout=10, context=ctx) as r:
    s_data = json.loads(r.read().decode('utf-8'))
    prods = s_data.get('data', {}).get('products', [])
    print(f"Search 'sut' found: {len(prods)} products")
    if prods:
        p0 = prods[0]
        print("Product 0 name:", p0.get('name'))
        print("Product 0 brand:", p0.get('brand', {}).get('name') if isinstance(p0.get('brand'), dict) else p0.get('brand'))
        print("Product 0 id:", p0.get('id'))
        print("Product 0 barcode info:", {k: v for k, v in p0.items() if 'code' in k.lower() or 'bar' in k.lower() or 'id' in k.lower()})

        # fetch full product detail
        p_id = p0.get('id')
        detail_url = f'https://www.migros.com.tr/rest/products/{p_id}'
        req_d = urllib.request.Request(detail_url, headers=headers)
        with urllib.request.urlopen(req_d, timeout=10, context=ctx) as rd:
            det = json.loads(rd.read().decode('utf-8'))
            det_data = det.get('data', {})
            print("Detail data keys:", list(det_data.keys()))
            for key in ['barcode', 'barcodes', 'ingredients', 'nutritionalValues', 'contents', 'description', 'brand']:
                if key in det_data:
                    print(f"Detail [{key}]:", str(det_data[key])[:300])
