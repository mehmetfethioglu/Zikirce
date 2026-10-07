import urllib.request
import json
import ssl

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

# 1. Test Migros products in a category
def test_migros():
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Accept': 'application/json',
        'Accept-Language': 'tr-TR,tr;q=0.9',
    }
    url = 'https://www.migros.com.tr/rest/products/search?category=sut-kahvaltilik-c-4&page=1&size=5'
    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=10, context=ctx) as r:
            res = json.loads(r.read().decode('utf-8'))
            print("Migros products response keys:", list(res.keys()))
            data = res.get('data', {})
            products = data.get('products', [])
            print(f"Migros products count: {len(products)}")
            if products:
                p = products[0]
                print("Migros product keys:", list(p.keys()))
                print("Migros barcode / id:", p.get('barcode'), p.get('id'), p.get('name'), p.get('brand'))
                # check details endpoint
                prod_id = p.get('id')
                detail_url = f'https://www.migros.com.tr/rest/products/{prod_id}'
                req_d = urllib.request.Request(detail_url, headers=headers)
                with urllib.request.urlopen(req_d, timeout=10, context=ctx) as rd:
                    det = json.loads(rd.read().decode('utf-8'))
                    det_data = det.get('data', {})
                    print("Detail keys:", list(det_data.keys()))
                    desc = det_data.get('description', '')
                    print("Description preview:", desc[:200] if desc else 'No description')
                    print("NutritionalValues:", det_data.get('nutritionalValues') or det_data.get('nutrition'))
                    print("Ingredients:", det_data.get('ingredients') or det_data.get('ingredientsText'))
    except Exception as e:
        print("Migros error:", e)

# 2. Test SOK with Mobile App Headers
def test_sok():
    headers = {
        'User-Agent': 'CepteSok/2.15.0 (Android; 13; en-US; Scale/3.00)',
        'Accept': 'application/json',
        'Accept-Encoding': 'gzip, deflate',
        'Host': 'api.ceptesok.com',
    }
    try:
        req = urllib.request.Request('https://api.ceptesok.com/v1/categories', headers=headers)
        with urllib.request.urlopen(req, timeout=10, context=ctx) as r:
            print("SOK mobile status:", r.status)
    except Exception as e:
        print("SOK mobile error:", e)

# 3. Test SOK web public endpoint
def test_sok_web():
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Accept': 'application/json',
    }
    try:
        req = urllib.request.Request('https://www.sokmarket.com.tr/api/categories', headers=headers)
        with urllib.request.urlopen(req, timeout=10, context=ctx) as r:
            print("SOK web status:", r.status)
    except Exception as e:
        print("SOK web error:", e)

if __name__ == '__main__':
    test_migros()
    test_sok()
    test_sok_web()
