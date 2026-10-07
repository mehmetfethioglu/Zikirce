import urllib.request
import json
import ssl
import sys

sys.stdout.reconfigure(encoding='utf-8')
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Content-Type': 'application/json',
    'Accept': 'application/json',
}

# Test 1: Search by barcode '8690504008782' (Ülker Çikolatalı Gofret)
barcodes = ['8690504008782', '8690526069500', '8690533000015']
for bc in barcodes:
    data = json.dumps({'keywords': bc}).encode('utf-8')
    req = urllib.request.Request('https://api.marketfiyati.org.tr/api/v2/search', data=data, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=10, context=ctx) as r:
            res = json.loads(r.read().decode('utf-8'))
            print(f"Barcode {bc} found: {res.get('numberOfFound')}")
            for item in res.get('content', []):
                print(f"  -> Title: {item.get('title')} | Brand: {item.get('brand')} | ID: {item.get('id')}")
    except Exception as e:
        print(f"Error {bc}:", e)
